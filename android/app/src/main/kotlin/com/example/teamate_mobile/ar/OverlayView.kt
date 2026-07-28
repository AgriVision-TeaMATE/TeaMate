package com.example.teamate_mobile.ar

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot

/**
 * Transparent overlay drawn on top of the ARCore camera preview: placed point dots, connecting
 * lines (open path while <4 points, closed/filled quad at 4), per-edge length labels, and a
 * reticle when no points are placed yet. Also captures raw touch input and forwards it to
 * [touchListener] - hit-testing against real anchors happens on the GL thread in ArCaptureView,
 * since it needs the current ARCore Frame.
 */
class OverlayView(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {

    interface TouchListener {
        fun onTouchDown(x: Float, y: Float)
        fun onTouchMove(x: Float, y: Float)
        fun onTouchUp(x: Float, y: Float)
    }

    var touchListener: TouchListener? = null

    /** Touch radius (px) used both here for hit-testing hints and by ArCaptureView for drag pickup. */
    val touchRadiusPx = 40f
    private val dragSlopPx = 18f

    @Volatile private var points: List<PointF> = emptyList()
    @Volatile private var edgeLengths: List<Float> = emptyList()
    @Volatile private var pointLabels: List<Int> = emptyList()
    @Volatile private var warnings: List<String> = emptyList()
    @Volatile private var draggingIndex: Int = -1
    @Volatile private var trackingOk: Boolean = true
    @Volatile private var reticle: PointF? = null

    private val pointPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#4CAF50")
        style = Paint.Style.FILL
    }
    private val draggingPointPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#FFC107")
        style = Paint.Style.FILL
    }
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 5f
    }
    private val warnLinePaint = Paint(linePaint).apply {
        color = Color.parseColor("#FF5252")
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#334CAF50")
        style = Paint.Style.FILL
    }
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 32f
        textAlign = Paint.Align.CENTER
        setShadowLayer(4f, 0f, 0f, Color.BLACK)
    }
    private val pointIndexPaint = Paint(labelPaint).apply {
        textAlign = Paint.Align.LEFT
    }
    private val reticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 3f
        alpha = 160
    }

    private val pointRadiusPx = 22f

    /** Pushes fresh render state; safe to call from any thread (posts an animation-aligned invalidate). */
    fun update(
        points: List<PointF>,
        edgeLengths: List<Float>,
        pointLabels: List<Int>,
        areaSqm: Float?,
        warnings: List<String>,
        draggingIndex: Int,
        trackingOk: Boolean,
        reticle: PointF?,
    ) {
        this.points = points
        this.edgeLengths = edgeLengths
        this.pointLabels = pointLabels
        this.warnings = warnings
        this.draggingIndex = draggingIndex
        this.trackingOk = trackingOk
        this.reticle = reticle
        postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!trackingOk) return

        reticle?.let { canvas.drawCircle(it.x, it.y, 16f, reticlePaint) }

        val pts = points
        val labels = pointLabels
        val n = pts.size
        if (n >= 2) {
            val closed = n >= 4
            val stroke = if (warnings.contains(AreaMath.WARNING_NON_CONVEX)) warnLinePaint else linePaint
            val path = Path()
            path.moveTo(pts[0].x, pts[0].y)
            for (i in 1 until n) path.lineTo(pts[i].x, pts[i].y)
            if (closed) {
                path.close()
                canvas.drawPath(path, fillPaint)
            }
            canvas.drawPath(path, stroke)

            for (i in edgeLengths.indices) {
                val a = pts[i]
                val b = pts[(i + 1) % n]
                val midX = (a.x + b.x) / 2f
                val midY = (a.y + b.y) / 2f
                canvas.drawText(String.format("%.2f m", edgeLengths[i]), midX, midY, labelPaint)
            }
        }

        for ((i, p) in pts.withIndex()) {
            val paint = if (i == draggingIndex) draggingPointPaint else pointPaint
            canvas.drawCircle(p.x, p.y, pointRadiusPx, paint)
            val label = labels.getOrNull(i)?.plus(1) ?: (i + 1)
            canvas.drawText(label.toString(), p.x + pointRadiusPx + 8f, p.y + 10f, pointIndexPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> touchListener?.onTouchDown(event.x, event.y)
            MotionEvent.ACTION_MOVE -> touchListener?.onTouchMove(event.x, event.y)
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> touchListener?.onTouchUp(event.x, event.y)
        }
        return true
    }

    /** Convenience for ArCaptureView's nearest-point pick, kept here so the radius stays in sync. */
    fun indexNear(x: Float, y: Float, candidates: List<PointF>): Int {
        var bestIdx = -1
        var bestDist = touchRadiusPx
        for ((i, p) in candidates.withIndex()) {
            val d = hypot((p.x - x).toDouble(), (p.y - y).toDouble()).toFloat()
            if (d <= bestDist) {
                bestDist = d
                bestIdx = i
            }
        }
        return bestIdx
    }

    fun hasExceededDragSlop(startX: Float, startY: Float, endX: Float, endY: Float): Boolean {
        return hypot((endX - startX).toDouble(), (endY - startY).toDouble()) >= dragSlopPx
    }
}
