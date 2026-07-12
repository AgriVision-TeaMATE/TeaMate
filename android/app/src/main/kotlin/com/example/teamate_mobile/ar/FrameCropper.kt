package com.example.teamate_mobile.ar

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.opengl.Matrix as GlMatrix
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import kotlin.math.abs

/**
 * Grabs the clean (overlay-free) camera frame at confirm time, maps the 4 ordered world-space
 * corners into camera image-pixel space via ARCore's own coordinate transform (so sensor
 * orientation/crop differences between the display and raw sensor image are handled by ARCore
 * rather than reimplemented here), and perspective-rectifies that quad into an upright JPEG.
 */
object FrameCropper {

    data class Result(val filePath: String, val imageCorners: List<PointF>)

    private const val MAX_OUTPUT_DIMENSION = 2000
    private const val JPEG_QUALITY = 90

    fun captureAndCrop(frame: Frame, orderedWorldPoints: List<AreaMath.Vec3>, activity: Activity): Result {
        val image = frame.acquireCameraImage()
        val sourceBitmap: Bitmap
        try {
            sourceBitmap = yuvImageToBitmap(image)
        } finally {
            image.close()
        }

        val camera = frame.camera
        val viewMatrix = FloatArray(16)
        val projMatrix = FloatArray(16)
        camera.getViewMatrix(viewMatrix, 0)
        camera.getProjectionMatrix(projMatrix, 0, 0.05f, 50.0f)

        val viewNormalized = FloatArray(orderedWorldPoints.size * 2)
        for ((i, p) in orderedWorldPoints.withIndex()) {
            val (ndcX, ndcY) = projectToNdc(p, viewMatrix, projMatrix)
            viewNormalized[i * 2] = ndcX * 0.5f + 0.5f
            viewNormalized[i * 2 + 1] = 1f - (ndcY * 0.5f + 0.5f)
        }

        val imagePixels = FloatArray(viewNormalized.size)
        frame.transformCoordinates2d(
            Coordinates2d.VIEW_NORMALIZED,
            viewNormalized,
            Coordinates2d.IMAGE_PIXELS,
            imagePixels,
        )

        val corners = orderedWorldPoints.indices.map { i -> PointF(imagePixels[i * 2], imagePixels[i * 2 + 1]) }

        val (outW, outH) = outputSizeFor(orderedWorldPoints)
        val cropped = perspectiveCrop(sourceBitmap, corners, outW, outH)

        val file = File(activity.cacheDir, "ar_crop_${System.currentTimeMillis()}.jpg")
        FileOutputStream(file).use { out -> cropped.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out) }

        return Result(file.absolutePath, corners)
    }

    private fun projectToNdc(p: AreaMath.Vec3, viewMatrix: FloatArray, projMatrix: FloatArray): Pair<Float, Float> {
        val vpMatrix = FloatArray(16)
        GlMatrix.multiplyMM(vpMatrix, 0, projMatrix, 0, viewMatrix, 0)
        val clip = FloatArray(4)
        GlMatrix.multiplyMV(clip, 0, vpMatrix, 0, floatArrayOf(p.x, p.y, p.z, 1f), 0)
        val w = if (abs(clip[3]) < 1e-6f) 1e-6f else clip[3]
        return Pair(clip[0] / w, clip[1] / w)
    }

    /** Sizes the output to preserve the sampled quad's real-world aspect ratio, capped for memory. */
    private fun outputSizeFor(points: List<AreaMath.Vec3>): Pair<Int, Int> {
        if (points.size < 4) return Pair(512, 512)
        val edgeTop = (points[1] - points[0]).length()
        val edgeRight = (points[2] - points[1]).length()
        val edgeBottom = (points[3] - points[2]).length()
        val edgeLeft = (points[0] - points[3]).length()
        val widthM = (edgeTop + edgeBottom) / 2f
        val heightM = (edgeLeft + edgeRight) / 2f
        val aspect = if (heightM > 1e-4f) widthM / heightM else 1f
        return if (aspect >= 1f) {
            Pair(MAX_OUTPUT_DIMENSION, (MAX_OUTPUT_DIMENSION / aspect).toInt().coerceAtLeast(1))
        } else {
            Pair((MAX_OUTPUT_DIMENSION * aspect).toInt().coerceAtLeast(1), MAX_OUTPUT_DIMENSION)
        }
    }

    /**
     * Perspective-correct crop via [Matrix.setPolyToPoly]: 4 point-correspondences yield a full
     * projective transform (not just affine), so this maps the tapped quad exactly onto the
     * output rectangle regardless of viewing angle.
     */
    private fun perspectiveCrop(src: Bitmap, corners: List<PointF>, outW: Int, outH: Int): Bitmap {
        val srcPts = floatArrayOf(
            corners[0].x, corners[0].y,
            corners[1].x, corners[1].y,
            corners[2].x, corners[2].y,
            corners[3].x, corners[3].y,
        )
        val dstPts = floatArrayOf(
            0f, 0f,
            outW.toFloat(), 0f,
            outW.toFloat(), outH.toFloat(),
            0f, outH.toFloat(),
        )
        val matrix = Matrix()
        matrix.setPolyToPoly(srcPts, 0, dstPts, 0, 4)

        val output = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        canvas.drawBitmap(src, matrix, paint)
        return output
    }

    /**
     * Converts a YUV_420_888 camera image to NV21 respecting each plane's rowStride/pixelStride -
     * camera planes are commonly semi-planar (chroma pixelStride == 2), so a naive sequential
     * buffer read here would produce a visibly corrupted (striped/color-noise) image.
     */
    private fun yuvImageToBitmap(image: Image): Bitmap {
        val width = image.width
        val height = image.height
        val yPlane = image.planes[0]
        val uPlane = image.planes[1]
        val vPlane = image.planes[2]

        val nv21 = ByteArray(width * height + 2 * (width / 2) * (height / 2))
        var pos = 0

        val yBuffer = yPlane.buffer
        val yRowStride = yPlane.rowStride
        val yPixelStride = yPlane.pixelStride
        if (yRowStride == width && yPixelStride == 1) {
            yBuffer.get(nv21, 0, width * height)
            pos = width * height
        } else {
            val row = ByteArray(yRowStride)
            for (r in 0 until height) {
                yBuffer.position(r * yRowStride)
                val len = minOf(yRowStride, yBuffer.remaining())
                yBuffer.get(row, 0, len)
                for (c in 0 until width) nv21[pos++] = row[c * yPixelStride]
            }
        }

        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        val uRowStride = uPlane.rowStride
        val uPixelStride = uPlane.pixelStride
        val vRowStride = vPlane.rowStride
        val vPixelStride = vPlane.pixelStride
        val chromaWidth = width / 2
        val chromaHeight = height / 2
        val uRow = ByteArray(uRowStride)
        val vRow = ByteArray(vRowStride)
        for (r in 0 until chromaHeight) {
            uBuffer.position(r * uRowStride)
            uBuffer.get(uRow, 0, minOf(uRowStride, uBuffer.remaining()))
            vBuffer.position(r * vRowStride)
            vBuffer.get(vRow, 0, minOf(vRowStride, vBuffer.remaining()))
            for (c in 0 until chromaWidth) {
                // NV21 = Y plane followed by interleaved V,U
                nv21[pos++] = vRow[c * vPixelStride]
                nv21[pos++] = uRow[c * uPixelStride]
            }
        }

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 95, out)
        val bytes = out.toByteArray()
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }
}
