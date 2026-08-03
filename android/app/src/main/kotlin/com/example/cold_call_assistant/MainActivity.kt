package com.example.cold_call_assistant

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val overlayChannelName = "com.example.cold_call_assistant/overlay"

    /**
     * MethodChannel shared between the handler (set in [configureFlutterEngine])
     * and the overlay-tap forwarder (used in [onResume]).
     *
     * Lateinit is safe because [configureFlutterEngine] is always called before
     * [onResume] in the Flutter activity lifecycle.
     */
    private lateinit var overlayChannel: MethodChannel

    // ── Render mode ────────────────────────────────────────────────────────

    // Switch from FlutterSurfaceView (SurfaceView-backed) to FlutterTextureView
    // (TextureView-backed). TextureView participates in the normal View draw
    // cycle and does NOT have an independent surface lifecycle, which prevents
    // the GPU pipeline stall that causes a black screen when the activity rapidly
    // transitions between onPause/onResume without a full onStop/onStart cycle
    // (e.g. when a call is cancelled before connecting).
    override fun getRenderMode(): RenderMode = RenderMode.texture

    // ── Flutter engine configuration ───────────────────────────────────────

    /**
     * Sets up the [overlayChannel] MethodChannel and registers Flutter → native
     * method handlers for overlay management.
     *
     * Called once when the Flutter engine is attached, before [onResume].
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        overlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            overlayChannelName,
        )

        overlayChannel.setMethodCallHandler { call, result ->
            when (call.method) {

                // Flutter asks us to start the overlay service.
                "showOverlay" -> {
                    val contactId = call.argument<String>("contactId") ?: ""
                    val serviceIntent = Intent(this, FloatingOverlayService::class.java).apply {
                        putExtra(FloatingOverlayService.EXTRA_CONTACT_ID, contactId)
                    }
                    startService(serviceIntent)
                    Log.d("CCA_OVERLAY", "showOverlay — contactId=$contactId")
                    result.success(null)
                }

                // Flutter asks us to stop the overlay service.
                "hideOverlay" -> {
                    FloatingOverlayService.pendingContactId = null
                    stopService(Intent(this, FloatingOverlayService::class.java))
                    Log.d("CCA_OVERLAY", "hideOverlay")
                    result.success(null)
                }

                // Flutter asks whether SYSTEM_ALERT_WINDOW is granted.
                "checkPermission" -> {
                    val granted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        android.provider.Settings.canDrawOverlays(this)
                    } else {
                        // Below API 23 the permission is granted at install time.
                        true
                    }
                    result.success(granted)
                }

                // Flutter asks us to open the system overlay settings screen.
                "requestPermission" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        val intent = Intent(
                            android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Activity lifecycle ─────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("CCA_LIFECYCLE", "onCreate")

        // Set the window background to white so that the brief gap between
        // Flutter's renderer re-attaching to the SurfaceTexture (after onStop)
        // and producing its first new frame does not appear as a black screen.
        //
        // Root cause confirmed by runtime logs (2026-08-02):
        //   When a phone call is placed via Intent.ACTION_CALL and immediately
        //   cancelled, two separate lifecycle cycles occur:
        //     Cycle 1: inactive → resumed  (no onStop, renderer stays attached)
        //     Cycle 2: inactive → hidden → paused  (onStop fires because the
        //              system Phone app processes the cancelled call asynchronously
        //              and its activity briefly takes the foreground).
        //   On Cycle 2's return, the Flutter renderer re-attaches to a new blank
        //   SurfaceTexture. During the gap before Flutter's first rendered frame,
        //   the SurfaceTexture is all-zero (transparent), so whatever is behind
        //   the TextureView shows through. On many Android versions this is the
        //   window's default background, which can appear black.
        //   Setting the window background to white makes this gap invisible.
        window.decorView.setBackgroundColor(Color.WHITE)
    }

    override fun onResume() {
        super.onResume()
        Log.d("CCA_LIFECYCLE", "onResume")

        // ── Overlay button tap forwarding ──────────────────────────────────
        //
        // When the user taps the floating overlay button, FloatingOverlayService
        // sets pendingContactId and then calls startActivity to bring this
        // activity to the foreground. onResume fires reliably regardless of
        // whether the activity was at the top of the stack (onNewIntent is not
        // guaranteed in all back-stack configurations).
        //
        // A 150ms delay gives the Flutter engine's message loop a frame or two
        // to stabilise after the activity resurfaces before we call into it.
        val contactId = FloatingOverlayService.pendingContactId
        if (contactId != null) {
            FloatingOverlayService.pendingContactId = null
            Log.d("CCA_OVERLAY", "onResume: forwarding overlay tap — contactId=$contactId")
            Handler(Looper.getMainLooper()).postDelayed({
                if (::overlayChannel.isInitialized) {
                    overlayChannel.invokeMethod("onOverlayButtonTapped", contactId)
                }
            }, 150)
        }
    }

    override fun onStart()   { super.onStart();   Log.d("CCA_LIFECYCLE", "onStart")   }
    override fun onPause()   { super.onPause();   Log.d("CCA_LIFECYCLE", "onPause")   }
    override fun onStop()    { super.onStop();    Log.d("CCA_LIFECYCLE", "onStop")    }
    override fun onRestart() { super.onRestart(); Log.d("CCA_LIFECYCLE", "onRestart") }
}
