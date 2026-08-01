package com.example.cold_call_assistant

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

    // ── Temporary lifecycle logging ───────────────────────────────────────────
    // Run `adb logcat -s CCA_LIFECYCLE` while testing to observe which callbacks
    // fire during: call initiation, fast cancel, normal call end.
    // These log lines can be removed once the fix is confirmed stable.

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("CCA_LIFECYCLE", "onCreate")
    }

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
