package com.example.teamate_mobile.ar

import android.app.Activity
import android.graphics.PointF
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.widget.FrameLayout
import com.google.ar.core.Anchor
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.abs

/**
 * PlatformView hosting the live AR capture UI: a GLSurfaceView rendering only the ARCore camera
 * background (see [BackgroundRenderer]) with a transparent [OverlayView] on top drawing the
 * point/line/area overlay. Owns the ARCore [Session] and all hit-testing/anchor state; the only
 * things crossing back to Flutter are cheap state events and the final confirm() result.
 */
class ArCaptureView(
    private val activity: Activity,
    @Suppress("unused") private val viewId: Int,
    private val methodChannel: MethodChannel,
) : PlatformView,
    GLSurfaceView.Renderer,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val container = FrameLayout(activity)
    private val glSurfaceView = GLSurfaceView(activity)
    private val overlayView = OverlayView(activity)
    private val backgroundRenderer = BackgroundRenderer()

    private var session: Session? = null

    private var viewportWidth = 1
    private var viewportHeight = 1

    private val anchors = mutableListOf<Anchor>()
    private var referencePlane: Plane? = null

    @Volatile private var draggingIndex: Int = -1
    private val touchLock = Object()
    private var pendingTapXY: FloatArray? = null
    private var pendingDragXY: FloatArray? = null

    @Volatile private var lastScreenPoints: List<PointF> = emptyList()

    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)

        container.addView(
            glSurfaceView,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT),
        )
        container.addView(
            overlayView,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT),
        )

        glSurfaceView.preserveEGLContextOnPause = true
        glSurfaceView.setEGLContextClientVersion(2)
        glSurfaceView.setRenderer(this)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

        overlayView.touchListener = object : OverlayView.TouchListener {
            override fun onTouchDown(x: Float, y: Float) = handleTouchDown(x, y)
            override fun onTouchMove(x: Float, y: Float) = handleTouchMove(x, y)
            override fun onTouchUp(x: Float, y: Float) = handleTouchUp(x, y)
        }

        startSession()
    }

    private fun startSession() {
        try {
            val s = Session(activity)
            val config = Config(s)
            config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
            config.focusMode = Config.FocusMode.AUTO
            config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            s.configure(config)
            session = s
        } catch (e: Exception) {
            emitEvent(mapOf("type" to "error", "code" to "SESSION_CREATE_FAILED", "message" to (e.message ?: "unknown")))
        }
    }

    // ---- touch handling (UI thread; actual hit-test happens on the GL thread) ----

    private fun handleTouchDown(x: Float, y: Float) {
        val idx = overlayView.indexNear(x, y, lastScreenPoints)
        if (idx != -1) {
            draggingIndex = idx
        } else if (anchors.size < 4) {
            synchronized(touchLock) { pendingTapXY = floatArrayOf(x, y) }
        }
    }

    private fun handleTouchMove(x: Float, y: Float) {
        if (draggingIndex != -1) {
            synchronized(touchLock) { pendingDragXY = floatArrayOf(x, y) }
        }
    }

    private fun handleTouchUp(x: Float, y: Float) {
        draggingIndex = -1
    }

    // ---- GLSurfaceView.Renderer (GL thread) ----

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        backgroundRenderer.createOnGlThread()
        session?.setCameraTextureName(backgroundRenderer.textureId)
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewportWidth = width
        viewportHeight = height
        GLES20.glViewport(0, 0, width, height)
        @Suppress("DEPRECATION")
        session?.setDisplayGeometry(activity.windowManager.defaultDisplay.rotation, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        val s = session ?: return
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

        val frame: Frame = try {
            s.update()
        } catch (e: CameraNotAvailableException) {
            return
        }

        backgroundRenderer.draw(frame)

        val camera = frame.camera
        val trackingOk = camera.trackingState == TrackingState.TRACKING

        if (!trackingOk) {
            lastScreenPoints = emptyList()
            postOverlayUpdate(emptyList(), emptyList(), null, emptyList(), -1, false, null)
            emitEvent(mapOf("type" to "tracking", "state" to "PAUSED"))
            return
        }

        consumeQueuedTap(frame)
        consumeQueuedDrag(frame)
        renderCurrentState(camera)
    }

    private fun consumeQueuedTap(frame: Frame) {
        val tapXY: FloatArray?
        synchronized(touchLock) {
            tapXY = pendingTapXY
            pendingTapXY = null
        }
        val (x, y) = tapXY ?: return
        if (anchors.size >= 4) return
        val hit = frame.hitTest(x, y).firstOrNull { h ->
            val trackable = h.trackable
            trackable is Plane && trackable.trackingState == TrackingState.TRACKING && trackable.isPoseInPolygon(h.hitPose)
        } ?: return
        if (referencePlane == null) referencePlane = hit.trackable as Plane
        anchors.add(hit.createAnchor())
        emitEvent(mapOf("type" to "pointsChanged", "count" to anchors.size))
    }

    private fun consumeQueuedDrag(frame: Frame) {
        val dragXY: FloatArray?
        synchronized(touchLock) {
            dragXY = pendingDragXY
            pendingDragXY = null
        }
        val (x, y) = dragXY ?: return
        val idx = draggingIndex
        if (idx !in anchors.indices) return
        val hit = frame.hitTest(x, y).firstOrNull { h ->
            val trackable = h.trackable
            trackable is Plane && trackable.trackingState == TrackingState.TRACKING && trackable.isPoseInPolygon(h.hitPose)
        } ?: return
        anchors[idx].detach()
        anchors[idx] = hit.createAnchor()
    }

    private fun renderCurrentState(camera: com.google.ar.core.Camera) {
        val worldPoints = anchors.map { a ->
            val t = a.pose.translation
            AreaMath.Vec3(t[0], t[1], t[2])
        }

        var screenPoints: List<PointF> = emptyList()
        var reticle: PointF? = null
        var quad: AreaMath.QuadResult? = null

        if (worldPoints.isNotEmpty()) {
            val viewMatrix = FloatArray(16)
            val projMatrix = FloatArray(16)
            camera.getViewMatrix(viewMatrix, 0)
            camera.getProjectionMatrix(projMatrix, 0, 0.05f, 50.0f)

            if (worldPoints.size >= 2) {
                quad = AreaMath.evaluate(worldPoints, currentPlaneNormal())
                screenPoints = quad.orderedPoints.map { projectToScreen(it, viewMatrix, projMatrix) }
            } else {
                screenPoints = listOf(projectToScreen(worldPoints[0], viewMatrix, projMatrix))
            }
        } else {
            reticle = PointF(viewportWidth / 2f, viewportHeight / 2f)
        }

        lastScreenPoints = screenPoints

        val closed = anchors.size >= 4
        val edgeLabels = quad?.let { AreaMath.edgeLengths(it.orderedPoints, closed) } ?: emptyList()
        val areaPreview = if (anchors.size >= 3) quad?.areaSqm else null

        postOverlayUpdate(screenPoints, edgeLabels, areaPreview, quad?.warnings ?: emptyList(), draggingIndex, true, reticle)

        if (anchors.size >= 3) {
            emitEvent(
                mapOf(
                    "type" to "pointsChanged",
                    "count" to anchors.size,
                    "areaPreviewSqm" to (areaPreview ?: 0f).toDouble(),
                ),
            )
        }
    }

    private fun currentPlaneNormal(): AreaMath.Vec3? {
        val p = referencePlane ?: return null
        val pose = p.centerPose
        val up = pose.transformPoint(floatArrayOf(0f, 1f, 0f))
        val origin = pose.translation
        return AreaMath.Vec3(up[0] - origin[0], up[1] - origin[1], up[2] - origin[2]).normalized()
    }

    private fun projectToScreen(p: AreaMath.Vec3, viewMatrix: FloatArray, projMatrix: FloatArray): PointF {
        val vpMatrix = FloatArray(16)
        Matrix.multiplyMM(vpMatrix, 0, projMatrix, 0, viewMatrix, 0)
        val clip = FloatArray(4)
        Matrix.multiplyMV(clip, 0, vpMatrix, 0, floatArrayOf(p.x, p.y, p.z, 1f), 0)
        val w = if (abs(clip[3]) < 1e-6f) 1e-6f else clip[3]
        val ndcX = clip[0] / w
        val ndcY = clip[1] / w
        val screenX = (ndcX * 0.5f + 0.5f) * viewportWidth
        val screenY = (1f - (ndcY * 0.5f + 0.5f)) * viewportHeight
        return PointF(screenX, screenY)
    }

    private fun postOverlayUpdate(
        points: List<PointF>,
        edges: List<Float>,
        area: Float?,
        warnings: List<String>,
        draggingIdx: Int,
        trackingOk: Boolean,
        reticle: PointF?,
    ) {
        activity.runOnUiThread { overlayView.update(points, edges, area, warnings, draggingIdx, trackingOk, reticle) }
    }

    // ---- MethodChannel ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "undoLastPoint" -> {
                if (anchors.isNotEmpty()) {
                    anchors.removeAt(anchors.size - 1).detach()
                    if (anchors.isEmpty()) referencePlane = null
                }
                result.success(anchors.size)
            }
            "reset" -> {
                anchors.forEach { it.detach() }
                anchors.clear()
                referencePlane = null
                result.success(null)
            }
            "confirmCapture" -> confirmCapture(result)
            "cancel" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    private fun confirmCapture(result: MethodChannel.Result) {
        val s = session
        if (s == null || anchors.size < 4) {
            result.error("NOT_READY", "Need 4 points placed before confirming", null)
            return
        }
        // Run on the GL thread: Session.update()/Frame access must happen on the thread that
        // owns the GL context driving the camera texture, not the platform-channel (UI) thread.
        glSurfaceView.queueEvent {
            try {
                val frame = s.update()
                val worldPoints = anchors.map { a ->
                    val t = a.pose.translation
                    AreaMath.Vec3(t[0], t[1], t[2])
                }
                val quad = AreaMath.evaluate(worldPoints, currentPlaneNormal())
                val cropResult = FrameCropper.captureAndCrop(frame, quad.orderedPoints, activity)
                val payload = mapOf(
                    "imagePath" to cropResult.filePath,
                    "areaSqm" to quad.areaSqm.toDouble(),
                    "corners3d" to quad.orderedPoints.map { mapOf("x" to it.x, "y" to it.y, "z" to it.z) },
                    "cornersImagePx" to cropResult.imageCorners.map { mapOf("x" to it.x, "y" to it.y) },
                    "warnings" to quad.warnings,
                )
                activity.runOnUiThread { result.success(payload) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("CAPTURE_FAILED", e.message, null) }
            }
        }
    }

    // ---- EventChannel.StreamHandler ----

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        activity.runOnUiThread { eventSink?.success(payload) }
    }

    // ---- PlatformView ----

    override fun getView() = container

    /** Forwarded from ArCapturePlugin's activity lifecycle observer - see its class doc. */
    fun onResume() {
        val s = session ?: return
        try {
            s.resume()
            glSurfaceView.onResume()
        } catch (e: CameraNotAvailableException) {
            emitEvent(mapOf("type" to "error", "code" to "CAMERA_NOT_AVAILABLE", "message" to (e.message ?: "")))
        }
    }

    fun onPause() {
        glSurfaceView.onPause()
        session?.pause()
    }

    override fun dispose() {
        anchors.forEach { it.detach() }
        anchors.clear()
        glSurfaceView.onPause()
        session?.close()
        session = null
        methodChannel.setMethodCallHandler(null)
    }
}
