package com.example.cold_call_assistant

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

/**
 * Draws a small draggable floating button above all other apps (including the
 * system Phone dialer) while a cold-call sequence is active.
 *
 * Lifecycle:
 *  - Started by [MainActivity] via MethodChannel when the user taps "Call".
 *  - Stopped by [MainActivity] when the sequence ends, is cancelled, or the
 *    overlay button itself is tapped.
 *
 * Communication back to Flutter:
 *  - When the button is tapped, [pendingContactId] is left set.
 *  - [returnToApp] brings [MainActivity] to the foreground.
 *  - [MainActivity.onResume] reads [pendingContactId] and calls back into Flutter
 *    via the MethodChannel, which then triggers navigation to PostCallReviewScreen.
 *
 * Permission required: android.permission.SYSTEM_ALERT_WINDOW
 * Overlay type: TYPE_APPLICATION_OVERLAY (API 26+) / TYPE_PHONE (API < 26)
 */
class FloatingOverlayService : Service() {

    companion object {
        const val EXTRA_CONTACT_ID = "contact_id"
        private const val TAG = "CCA_OVERLAY"

        /**
         * Holds the contactId of the last tapped overlay button so that
         * [MainActivity.onResume] can forward it to Flutter after the activity
         * resurfaces — without relying on onNewIntent delivery guarantees.
         *
         * Cleared by [MainActivity.onResume] immediately after being consumed.
         */
        @Volatile
        var pendingContactId: String? = null
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val contactId = intent?.getStringExtra(EXTRA_CONTACT_ID) ?: ""
        Log.d(TAG, "onStartCommand — contactId=$contactId")

        pendingContactId = contactId

        // Add the view only once; repeated starts just update the contactId.
        if (overlayView == null) {
            createOverlayView()
        }

        // START_NOT_STICKY: if the process is killed, do not restart.
        // The overlay only exists while a call sequence is active; it is
        // explicitly restarted by the next call if needed.
        return START_NOT_STICKY
    }

    // ── Overlay view creation ──────────────────────────────────────────────

    private fun createOverlayView() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val sizePx = dpToPx(64)

        // Round green container.
        val container = FrameLayout(this)
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            // Deep green matching the app's call button colour.
            setColor(Color.parseColor("#2E7D32"))
        }
        container.background = bg
        container.elevation = dpToPx(8).toFloat()

        // Phone emoji label — no vector assets needed for a system overlay service.
        val label = TextView(this).apply {
            text = "📞"
            textSize = 26f
            gravity = Gravity.CENTER
        }
        container.addView(
            label,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            sizePx, sizePx,
            layoutType,
            // FLAG_NOT_FOCUSABLE: prevents the overlay from consuming key events
            // so the Phone dialer remains fully interactive.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dpToPx(16)
            y = dpToPx(200)
        }

        // Drag support — distinguishes a drag from a tap by movement threshold.
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var wasDragged = false

        container.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    wasDragged = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    // Mirror the X axis: gravity=END, so moving finger left
                    // increases params.x (moves button right).
                    val dx = (initialTouchX - event.rawX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
                        wasDragged = true
                        params.x = initialX + dx
                        params.y = initialY + dy
                        windowManager?.updateViewLayout(overlayView, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!wasDragged) {
                        // Genuine tap — bring app to foreground.
                        Log.d(TAG, "Overlay tapped — returning to app")
                        returnToApp()
                    }
                    true
                }
                else -> false
            }
        }

        overlayView = container
        windowManager?.addView(container, params)
        Log.d(TAG, "Overlay view added to WindowManager")
    }

    // ── App return ─────────────────────────────────────────────────────────

    private fun returnToApp() {
        // pendingContactId is already set from onStartCommand.
        // MainActivity.onResume() will read and clear it, then forward to Flutter.
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
        startActivity(intent)
        stopSelf()
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private fun dpToPx(dp: Int): Int =
        (dp * resources.displayMetrics.density).toInt()

    // ── Cleanup ────────────────────────────────────────────────────────────

    override fun onDestroy() {
        super.onDestroy()
        overlayView?.let {
            try {
                windowManager?.removeView(it)
                Log.d(TAG, "Overlay view removed from WindowManager")
            } catch (e: Exception) {
                // The view may already be detached if the window was closed externally.
                Log.w(TAG, "removeView failed — view may already be detached: ${e.message}")
            }
        }
        overlayView = null
    }
}
