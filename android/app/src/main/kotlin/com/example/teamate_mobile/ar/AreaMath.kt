package com.example.teamate_mobile.ar

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

/** Real-world-space area/geometry math for the 4-point AR sampling quadrilateral. */
object AreaMath {

    const val WARNING_NON_CONVEX = "NON_CONVEX"
    const val WARNING_DEGENERATE = "DEGENERATE_AREA"
    const val WARNING_AREA_TOO_LARGE = "AREA_OUT_OF_BOUNDS"

    private const val MIN_AREA_SQM = 0.01f
    private const val MAX_AREA_SQM = 100f

    data class Vec3(val x: Float, val y: Float, val z: Float) {
        operator fun minus(o: Vec3) = Vec3(x - o.x, y - o.y, z - o.z)
        operator fun plus(o: Vec3) = Vec3(x + o.x, y + o.y, z + o.z)
        fun cross(o: Vec3) = Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x)
        fun dot(o: Vec3) = x * o.x + y * o.y + z * o.z
        fun length(): Float = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
        fun normalized(): Vec3 {
            val l = length()
            return if (l < 1e-8f) this else Vec3(x / l, y / l, z / l)
        }
    }

    data class QuadResult(
        val orderedPoints: List<Vec3>,
        val orderedIndices: List<Int>,
        val areaSqm: Float,
        val warnings: List<String>,
    )

    /** Newell's method: robust normal estimate for a (possibly non-planar/unordered) point set. */
    private fun planeNormalFallback(points: List<Vec3>): Vec3 {
        var nx = 0f
        var ny = 0f
        var nz = 0f
        val n = points.size
        for (i in 0 until n) {
            val cur = points[i]
            val next = points[(i + 1) % n]
            nx += (cur.y - next.y) * (cur.z + next.z)
            ny += (cur.z - next.z) * (cur.x + next.x)
            nz += (cur.x - next.x) * (cur.y + next.y)
        }
        return Vec3(nx, ny, nz).normalized()
    }

    private fun centroidOf(points: List<Vec3>): Vec3 {
        var sx = 0f
        var sy = 0f
        var sz = 0f
        for (p in points) {
            sx += p.x
            sy += p.y
            sz += p.z
        }
        val n = points.size.toFloat()
        return Vec3(sx / n, sy / n, sz / n)
    }

    /**
     * Orders points around their centroid by angle in-plane, repairing out-of-tap-order/bowtie
     * placement. [planeNormal] should come from the ARCore-detected plane the anchors sit on;
     * falls back to a Newell's-method estimate if unavailable or degenerate.
     */
    fun orderPoints(points: List<Vec3>, planeNormal: Vec3?): List<Vec3> {
        if (points.size < 3) return points
        val orderedIndices = orderPointIndices(points, planeNormal)
        return orderedIndices.map { points[it] }
    }

    fun orderPointIndices(points: List<Vec3>, planeNormal: Vec3?): List<Int> {
        if (points.size < 3) return points.indices.toList()
        val normal = planeNormal?.takeIf { it.length() > 1e-6f } ?: planeNormalFallback(points)
        val centroid = centroidOf(points)
        val arbitrary = if (abs(normal.x) < 0.9f) Vec3(1f, 0f, 0f) else Vec3(0f, 1f, 0f)
        val u = normal.cross(arbitrary).normalized()
        val v = normal.cross(u).normalized()
        return points.indices.sortedBy { index ->
            val p = points[index]
            val d = p - centroid
            atan2(d.dot(v).toDouble(), d.dot(u).toDouble())
        }
    }

    /** 3D generalization of the shoelace formula; robust to minor non-coplanar sensor noise. */
    fun computeArea(orderedPoints: List<Vec3>): Float {
        if (orderedPoints.size < 3) return 0f
        var sum = Vec3(0f, 0f, 0f)
        val n = orderedPoints.size
        for (i in 0 until n) {
            sum += orderedPoints[i].cross(orderedPoints[(i + 1) % n])
        }
        return 0.5f * sum.length()
    }

    /** Edge lengths in meters, in point order. [closed] includes the last->first wraparound edge. */
    fun edgeLengths(orderedPoints: List<Vec3>, closed: Boolean): List<Float> {
        val n = orderedPoints.size
        if (n < 2) return emptyList()
        val segments = if (closed) n else n - 1
        return (0 until segments).map { i -> (orderedPoints[(i + 1) % n] - orderedPoints[i]).length() }
    }

    fun isConvex(orderedPoints: List<Vec3>, normal: Vec3): Boolean {
        val n = orderedPoints.size
        if (n < 4) return true
        var sign = 0
        for (i in 0 until n) {
            val a = orderedPoints[i]
            val b = orderedPoints[(i + 1) % n]
            val c = orderedPoints[(i + 2) % n]
            val cross = (b - a).cross(c - b)
            val s = cross.dot(normal)
            val cur = when {
                s > 1e-6f -> 1
                s < -1e-6f -> -1
                else -> 0
            }
            if (cur == 0) continue
            if (sign == 0) sign = cur else if (cur != sign) return false
        }
        return true
    }

    /**
     * Orders the raw tapped/dragged points, computes area, and flags validity warnings.
     * Safe to call with 1-4 points; area is only meaningful once >= 3.
     */
    fun evaluate(rawPoints: List<Vec3>, planeNormal: Vec3?): QuadResult {
        val orderedIndices = orderPointIndices(rawPoints, planeNormal)
        val ordered = orderedIndices.map { rawPoints[it] }
        val normal = planeNormal?.takeIf { it.length() > 1e-6f } ?: planeNormalFallback(ordered)
        val area = computeArea(ordered)
        val warnings = mutableListOf<String>()
        if (ordered.size >= 3) {
            if (!isConvex(ordered, normal)) warnings.add(WARNING_NON_CONVEX)
            if (area < MIN_AREA_SQM) warnings.add(WARNING_DEGENERATE)
            if (area > MAX_AREA_SQM) warnings.add(WARNING_AREA_TOO_LARGE)
        }
        return QuadResult(ordered, orderedIndices, area, warnings)
    }
}
