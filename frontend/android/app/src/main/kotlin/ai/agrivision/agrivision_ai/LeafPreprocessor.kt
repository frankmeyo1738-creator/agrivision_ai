package ai.agrivision.agrivision_ai

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Image geometry and RGB bilinear filtering matching the PIL/TorchVision contract.
 * Separable antialiasing, normalized 22-bit coefficients and 8-bit intermediate
 * rounding follow Pillow's RGB resampling semantics (see deployment documentation).
 * Only the eventual center crop is materialized, avoiding long-edge allocations.
 */
object LeafPreprocessor {
    data class RgbImage(val width: Int, val height: Int, val pixels: IntArray)
    private data class Kernel(val start: Int, val weights: IntArray)
    private const val PRECISION = 22
    private const val UNIT = 1 shl PRECISION
    private val mean = floatArrayOf(.485f, .456f, .406f)
    private val std = floatArrayOf(.229f, .224f, .225f)

    fun orient(image: RgbImage, orientation: Int): RgbImage {
        if (orientation !in 2..8) return image
        val swapped = orientation >= 5
        val w = if (swapped) image.height else image.width
        val h = if (swapped) image.width else image.height
        val output = IntArray(w * h)
        for (y in 0 until image.height) for (x in 0 until image.width) {
            val point = when (orientation) {
                2 -> Pair(image.width - 1 - x, y)
                3 -> Pair(image.width - 1 - x, image.height - 1 - y)
                4 -> Pair(x, image.height - 1 - y)
                5 -> Pair(y, x)
                6 -> Pair(image.height - 1 - y, x)
                7 -> Pair(image.height - 1 - y, image.width - 1 - x)
                else -> Pair(y, image.width - 1 - x)
            }
            output[point.second * w + point.first] = image.pixels[y * image.width + x]
        }
        return RgbImage(w, h, output)
    }

    fun tensor(image: RgbImage): FloatArray {
        val cropped = cropRgb(image)
        val output = FloatArray(3 * 224 * 224)
        for (i in cropped.indices) for (channel in 0..2) {
            val value = (cropped[i] ushr (16 - 8 * channel)) and 255
            output[channel * 224 * 224 + i] = (value / 255f - mean[channel]) / std[channel]
        }
        return output
    }

    fun cropRgb(image: RgbImage): IntArray {
        require(image.width > 0 && image.height > 0)
        require(image.pixels.size == image.width * image.height)
        // TorchVision integer short-edge resize truncates the proportional long edge.
        val w: Int
        val h: Int
        if (image.width <= image.height) {
            w = 256
            h = (256L * image.height / image.width).toInt()
        } else {
            h = 256
            w = (256L * image.width / image.height).toInt()
        }
        // Python round() uses ties-to-even, unlike Kotlin roundToInt().
        val left = Math.rint((w - 224) / 2.0).toInt()
        val top = Math.rint((h - 224) / 2.0).toInt()
        val xKernels = Array(224) { kernel(image.width, w, left + it) }
        val yKernels = Array(224) { kernel(image.height, h, top + it) }
        val horizontal = IntArray(224 * image.height)
        for (y in 0 until image.height) for (x in 0 until 224) {
            val k = xKernels[x]
            var pixel = 0
            for (channel in 0..2) {
                val shift = 16 - channel * 8
                var sum = UNIT / 2
                for (j in k.weights.indices) {
                    sum += ((image.pixels[y * image.width + k.start + j] ushr shift) and 255) * k.weights[j]
                }
                pixel = pixel or ((sum shr PRECISION).coerceIn(0, 255) shl shift)
            }
            horizontal[y * 224 + x] = pixel
        }
        val output = IntArray(224 * 224)
        for (y in 0 until 224) for (x in 0 until 224) {
            val k = yKernels[y]
            var pixel = 0
            for (channel in 0..2) {
                val shift = 16 - channel * 8
                var sum = UNIT / 2
                for (j in k.weights.indices) {
                    sum += ((horizontal[(k.start + j) * 224 + x] ushr shift) and 255) * k.weights[j]
                }
                pixel = pixel or ((sum shr PRECISION).coerceIn(0, 255) shl shift)
            }
            output[y * 224 + x] = pixel
        }
        return output
    }

    private fun kernel(input: Int, output: Int, position: Int): Kernel {
        if (input == output) return Kernel(position, intArrayOf(UNIT))
        val scale = input.toDouble() / output
        val filterScale = max(1.0, scale)
        val center = (position + .5) * scale
        // C integer casts truncate toward zero; preserve that behavior before clipping.
        val start = max(0, (center - filterScale + .5).toInt())
        val end = min(input, (center + filterScale + .5).toInt())
        val raw = DoubleArray(end - start) { max(0.0, 1.0 - abs((it + start - center + .5) / filterScale)) }
        val total = raw.sum()
        return Kernel(start, IntArray(raw.size) { (raw[it] / total * UNIT + .5).toInt() })
    }
}
