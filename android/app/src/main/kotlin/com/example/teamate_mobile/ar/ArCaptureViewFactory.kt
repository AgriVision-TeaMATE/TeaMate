package com.example.teamate_mobile.ar

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Creates one [ArCaptureView] per Flutter AndroidView instance, wiring its per-view
 * MethodChannel/EventChannel. Only one AR capture view is expected to be alive at a time (the
 * dedicated full-screen capture screen), so [activeView] is enough for [ArCapturePlugin] to
 * forward activity lifecycle events to it.
 */
class ArCaptureViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    var activeView: ArCaptureView? = null
        private set

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val activity = activityProvider() ?: throw IllegalStateException("No attached Activity for AR capture view")
        val methodChannel = MethodChannel(messenger, "com.teamate/ar_capture/$viewId")
        val eventChannel = EventChannel(messenger, "com.teamate/ar_capture/$viewId/events")
        val view = ArCaptureView(activity, viewId, methodChannel)
        eventChannel.setStreamHandler(view)
        activeView = view
        // Platform views are often created while the Activity is already resumed, so there may be
        // no subsequent ON_RESUME callback to start ARCore unless we do it here.
        view.onResume()
        return view
    }
}
