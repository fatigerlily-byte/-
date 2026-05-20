package com.ojisanwatch

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View

/**
 * おじさんの顔を Canvas で描画するカスタムビュー。
 * ViewBox は 200×220 の仮想座標系で設計し、実サイズにスケールする。
 */
class OjisanView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private val skinColor  = Color.parseColor("#F5C5A3")
    private val hairColor  = Color.parseColor("#4A3728")
    private val eyeColor   = Color.parseColor("#3E2723")
    private val noseColor  = Color.parseColor("#E8A87C")
    private val suitColor  = Color.parseColor("#3A5A9E")
    private val tieColor   = Color.parseColor("#C0392B")
    private val blushColor = Color.parseColor("#FFB3A7")
    private val mouthColor = Color.parseColor("#A0522D")
    private val wrinkleColor = Color.parseColor("#D4956A")
    private val glassLensColor = Color.parseColor("#C8E6FA")

    private val skinPaint    = fill(skinColor)
    private val hairPaint    = fill(hairColor)
    private val eyePaint     = fill(eyeColor)
    private val nosePaint    = fill(noseColor)
    private val nostrilPaint = fill(Color.parseColor("#D4956A"))
    private val suitPaint    = fill(suitColor)
    private val tiePaint     = fill(tieColor)
    private val blushPaint   = fill(blushColor).also { it.alpha = 115 }
    private val whitePaint   = fill(Color.WHITE)

    private val glassBorderPaint = stroke(hairColor, 4f)
    private val glassLensPaint   = fill(glassLensColor).also { it.alpha = 76 }
    private val mouthPaint       = stroke(mouthColor, 3f)
    private val browPaint        = stroke(hairColor, 6f)
    private val mustachePaint    = stroke(hairColor, 5f)
    private val wrinklePaint     = stroke(wrinkleColor, 1.5f)

    private val path = Path()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val s = minOf(width, height).toFloat()
        canvas.save()
        canvas.scale(s / 200f, s / 220f)
        drawAll(canvas)
        canvas.restore()
    }

    private fun drawAll(c: Canvas) {
        // ── スーツ & ネクタイ ──────────────────────────────────────────
        c.drawRect(72f, 185f, 128f, 220f, suitPaint)
        c.drawRect(85f, 180f, 115f, 195f, skinPaint) // 首

        path.reset()
        path.moveTo(100f, 188f); path.lineTo(108f, 204f)
        path.lineTo(100f, 220f); path.lineTo(92f, 204f); path.close()
        c.drawPath(path, tiePaint)

        // ── 顔の輪郭 ──────────────────────────────────────────────────
        c.drawOval(16f, 97f, 44f, 133f, skinPaint)  // 左耳
        c.drawOval(156f, 97f, 184f, 133f, skinPaint) // 右耳
        c.drawOval(28f, 38f, 172f, 195f, skinPaint)  // 顔

        // ── 髪型（薄い おじさん！）────────────────────────────────────
        path.reset()
        path.addArc(RectF(28f, 38f, 172f, 100f), 180f, 180f)
        path.close()
        c.drawPath(path, hairPaint) // 周辺の黒髪
        c.drawOval(58f, 38f, 142f, 76f, skinPaint) // ハゲ部分

        // ── シワ ──────────────────────────────────────────────────────
        path.reset(); path.moveTo(68f, 76f); path.quadTo(100f, 72f, 132f, 76f)
        c.drawPath(path, wrinklePaint)
        path.reset(); path.moveTo(74f, 84f); path.quadTo(100f, 80f, 126f, 84f)
        c.drawPath(path, wrinklePaint)

        // ── 眉毛（太い）──────────────────────────────────────────────
        path.reset(); path.moveTo(50f, 97f); path.quadTo(70f, 88f, 90f, 94f)
        c.drawPath(path, browPaint)
        path.reset(); path.moveTo(110f, 94f); path.quadTo(130f, 88f, 150f, 97f)
        c.drawPath(path, browPaint)

        // ── メガネ ────────────────────────────────────────────────────
        c.drawRoundRect(46f, 100f, 96f, 136f, 8f, 8f, glassLensPaint)
        c.drawRoundRect(104f, 100f, 154f, 136f, 8f, 8f, glassLensPaint)
        c.drawRoundRect(46f, 100f, 96f, 136f, 8f, 8f, glassBorderPaint)
        c.drawRoundRect(104f, 100f, 154f, 136f, 8f, 8f, glassBorderPaint)
        c.drawLine(96f, 118f, 104f, 118f, glassBorderPaint) // ブリッジ

        // ── 瞳 ────────────────────────────────────────────────────────
        c.drawCircle(71f, 118f, 10f, eyePaint)
        c.drawCircle(129f, 118f, 10f, eyePaint)
        c.drawCircle(75f, 114f, 3f, whitePaint) // 光
        c.drawCircle(133f, 114f, 3f, whitePaint)

        // ── 鼻 ────────────────────────────────────────────────────────
        c.drawOval(90f, 141f, 110f, 155f, nosePaint)
        c.drawCircle(94f, 151f, 4f, nostrilPaint)
        c.drawCircle(106f, 151f, 4f, nostrilPaint)

        // ── ほっぺ ────────────────────────────────────────────────────
        c.drawOval(37f, 137f, 73f, 161f, blushPaint)
        c.drawOval(127f, 137f, 163f, 161f, blushPaint)

        // ── 口ひげ（おじさん！）───────────────────────────────────────
        path.reset()
        path.moveTo(80f, 163f); path.quadTo(91f, 156f, 100f, 161f)
        path.quadTo(109f, 156f, 120f, 163f)
        c.drawPath(path, mustachePaint)

        // ── 口（困り顔）──────────────────────────────────────────────
        path.reset()
        path.moveTo(78f, 173f); path.quadTo(100f, 182f, 122f, 173f)
        c.drawPath(path, mouthPaint)
    }

    // ── ユーティリティ ────────────────────────────────────────────────
    private fun fill(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        style = Paint.Style.FILL
    }

    private fun stroke(color: Int, width: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        style = Paint.Style.STROKE
        strokeWidth = width
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
}
