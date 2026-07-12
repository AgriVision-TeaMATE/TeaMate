package com.example.teamate_mobile.ar

import android.app.Activity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * App-level entry point: registers the AR capture PlatformView factory and the
 * availability/install-flow MethodChannel, and forwards Activity lifecycle (resume/pause) to
 * whichever [ArCaptureView] is currently alive - ARCore holds an exclusive camera lock, so a
 * missed pause/resume here would leak the camera and break the existing image_picker camera
 * path used by the Upload Image flow.
 */
class ArCapturePlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private var appChannel: MethodChannel? = null
    private var activity: Activity? = null
    private var viewFactory: ArCaptureViewFactory? = null

    private var lifecycle: Lifecycle? = null
    private var lifecycleObserver: LifecycleEventObserver? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appChannel = MethodChannel(binding.binaryMessenger, "com.teamate/ar_capture").also {
            it.setMethodCallHandler(this)
        }
        val factory = ArCaptureViewFactory(binding.binaryMessenger) { activity }
        viewFactory = factory
        binding.platformViewRegistry.registerViewFactory("com.teamate/ar_capture_view", factory)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appChannel?.setMethodCallHandler(null)
        appChannel = null
        viewFactory = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        attachLifecycleObserver(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        attachLifecycleObserver(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachLifecycleObserver()
        activity = null
    }

    override fun onDetachedFromActivity() {
        detachLifecycleObserver()
        activity = null
    }

    private fun attachLifecycleObserver(binding: ActivityPluginBinding) {
        detachLifecycleObserver()
        val lc = FlutterLifecycleAdapter.getActivityLifecycle(binding)
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> viewFactory?.activeView?.onResume()
                Lifecycle.Event.ON_PAUSE -> viewFactory?.activeView?.onPause()
                else -> {}
            }
        }
        lc.addObserver(observer)
        lifecycle = lc
        lifecycleObserver = observer
    }

    private fun detachLifecycleObserver() {
        lifecycleObserver?.let { lifecycle?.removeObserver(it) }
        lifecycle = null
        lifecycleObserver = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not attached", null)
            return
        }
        when (call.method) {
            "checkAvailability" -> result.success(ArAvailabilityHelper.checkAvailability(act))
            "requestInstall" -> {
                val userRequested = call.argument<Boolean>("userRequestedInstall") ?: true
                result.success(ArAvailabilityHelper.requestInstall(act, userRequested))
            }
            else -> result.notImplemented()
        }
    }
}
