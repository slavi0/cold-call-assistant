package com.example.cold_call_assistant

import android.graphics.Color
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {

    // Switch from the default FlutterSurfaceView (SurfaceView-backed) to
    // FlutterTextureView (TextureView-backed). TextureView participates in the
    // normal View draw cycle and does NOT have an independent surface lifecycle,
    // which prevents the GPU pipeline stall that causes a black screen when the
    // activity rapidly transitions between onPause/onResume without a full
    // onStop/onStart cycle (e.g. when a call is cancelled before connecting).
    override fun getRenderMode(): RenderMode = RenderMode.texture

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

    // ── Lifecycle logging ─────────────────────────────────────────────────────
    // Run `adb logcat -s CCA_LIFECYCLE` to observe the two-cycle pattern.

    override fun onStart() {
        super.onStart()
        Log.d("CCA_LIFECYCLE", "onStart")
    }

    override fun onResume() {
        super.onResume()
        Log.d("CCA_LIFECYCLE", "onResume")
    }

    override fun onPause() {
        super.onPause()
        Log.d("CCA_LIFECYCLE", "onPause")
    }

    override fun onStop() {
        super.onStop()
        Log.d("CCA_LIFECYCLE", "onStop")
    }

    override fun onRestart() {
        super.onRestart()
        Log.d("CCA_LIFECYCLE", "onRestart")
    }
}
