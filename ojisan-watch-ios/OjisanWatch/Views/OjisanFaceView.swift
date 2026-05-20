import SwiftUI

/// SwiftUI Canvas でおじさんの顔を描画するビュー。
/// 仮想座標系 200×220 で設計し、実際のサイズにスケーリングする。
struct OjisanFaceView: View {

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width / 200, size.height / 220)
            ctx.concatenate(CGAffineTransform(scaleX: scale, y: scale))
            drawAll(in: &ctx)
        }
    }

    // swiftlint:disable function_body_length
    private func drawAll(in ctx: inout GraphicsContext) {

        // ── カラーパレット ─────────────────────────────────────────
        let skin     = Color(red: 0.96, green: 0.77, blue: 0.64)
        let hair     = Color(red: 0.29, green: 0.22, blue: 0.16)
        let eyeColor = Color(red: 0.24, green: 0.15, blue: 0.14)
        let suit     = Color(red: 0.23, green: 0.35, blue: 0.62)
        let tie      = Color(red: 0.75, green: 0.22, blue: 0.17)
        let blush    = Color(red: 1.0,  green: 0.70, blue: 0.65).opacity(0.45)
        let glassLens = Color(red: 0.78, green: 0.90, blue: 0.98).opacity(0.30)
        let glassRim = Color(red: 0.17, green: 0.10, blue: 0.06)
        let mouthC   = Color(red: 0.63, green: 0.32, blue: 0.18)
        let wrinkleC = Color(red: 0.83, green: 0.58, blue: 0.42)
        let noseC    = Color(red: 0.91, green: 0.66, blue: 0.49)

        // ── スーツ & ネクタイ ──────────────────────────────────────
        ctx.fill(Path(CGRect(x: 72, y: 185, width: 56, height: 35)), with: .color(suit))
        ctx.fill(Path { p in
            p.move(to: .init(x: 100, y: 188)); p.addLine(to: .init(x: 108, y: 204))
            p.addLine(to: .init(x: 100, y: 220)); p.addLine(to: .init(x: 92, y: 204))
            p.closeSubpath()
        }, with: .color(tie))

        // ── 首 ────────────────────────────────────────────────────
        ctx.fill(Path(CGRect(x: 85, y: 172, width: 30, height: 22)), with: .color(skin))

        // ── 耳 ────────────────────────────────────────────────────
        ctx.fill(Path(ellipseIn: .init(x: 16, y: 97, width: 28, height: 36)), with: .color(skin))
        ctx.fill(Path(ellipseIn: .init(x: 156, y: 97, width: 28, height: 36)), with: .color(skin))

        // ── 顔輪郭 ────────────────────────────────────────────────
        ctx.fill(Path(ellipseIn: .init(x: 28, y: 38, width: 144, height: 157)), with: .color(skin))

        // ── 髪（薄い おじさん！）──────────────────────────────────
        ctx.fill(Path { p in
            p.addArc(center: .init(x: 100, y: 110),
                     radius: 72, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.closeSubpath()
        }, with: .color(hair))
        // ハゲ部分（肌色で上書き）
        ctx.fill(Path(ellipseIn: .init(x: 58, y: 38, width: 84, height: 38)), with: .color(skin))

        // ── シワ ──────────────────────────────────────────────────
        ctx.stroke(Path { p in
            p.move(to: .init(x: 68, y: 76))
            p.addQuadCurve(to: .init(x: 132, y: 76), control: .init(x: 100, y: 72))
        }, with: .color(wrinkleC), lineWidth: 1.5)
        ctx.stroke(Path { p in
            p.move(to: .init(x: 74, y: 84))
            p.addQuadCurve(to: .init(x: 126, y: 84), control: .init(x: 100, y: 80))
        }, with: .color(wrinkleC), lineWidth: 1)

        // ── 眉毛（太い）──────────────────────────────────────────
        let browStyle = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        ctx.stroke(Path { p in
            p.move(to: .init(x: 50, y: 97))
            p.addQuadCurve(to: .init(x: 90, y: 94), control: .init(x: 70, y: 88))
        }, with: .color(hair), style: browStyle)
        ctx.stroke(Path { p in
            p.move(to: .init(x: 110, y: 94))
            p.addQuadCurve(to: .init(x: 150, y: 97), control: .init(x: 130, y: 88))
        }, with: .color(hair), style: browStyle)

        // ── メガネ ────────────────────────────────────────────────
        ctx.fill(Path(roundedRect: .init(x: 46, y: 100, width: 50, height: 36), cornerRadius: 8),
                 with: .color(glassLens))
        ctx.fill(Path(roundedRect: .init(x: 104, y: 100, width: 50, height: 36), cornerRadius: 8),
                 with: .color(glassLens))
        let glassRimStyle = StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
        ctx.stroke(Path(roundedRect: .init(x: 46, y: 100, width: 50, height: 36), cornerRadius: 8),
                   with: .color(glassRim), style: glassRimStyle)
        ctx.stroke(Path(roundedRect: .init(x: 104, y: 100, width: 50, height: 36), cornerRadius: 8),
                   with: .color(glassRim), style: glassRimStyle)
        // ブリッジ
        ctx.stroke(Path { p in
            p.move(to: .init(x: 96, y: 118)); p.addLine(to: .init(x: 104, y: 118))
        }, with: .color(glassRim), lineWidth: 3.5)

        // ── 瞳 ────────────────────────────────────────────────────
        ctx.fill(Path(ellipseIn: .init(x: 61, y: 108, width: 20, height: 20)), with: .color(eyeColor))
        ctx.fill(Path(ellipseIn: .init(x: 119, y: 108, width: 20, height: 20)), with: .color(eyeColor))
        ctx.fill(Path(ellipseIn: .init(x: 72, y: 111, width: 6, height: 6)), with: .color(.white))
        ctx.fill(Path(ellipseIn: .init(x: 130, y: 111, width: 6, height: 6)), with: .color(.white))

        // ── 鼻 ────────────────────────────────────────────────────
        ctx.fill(Path(ellipseIn: .init(x: 90, y: 141, width: 20, height: 14)), with: .color(noseC))
        ctx.fill(Path(ellipseIn: .init(x: 90, y: 147, width: 8, height: 8)), with: .color(wrinkleC))
        ctx.fill(Path(ellipseIn: .init(x: 102, y: 147, width: 8, height: 8)), with: .color(wrinkleC))

        // ── ほっぺ ────────────────────────────────────────────────
        ctx.fill(Path(ellipseIn: .init(x: 37, y: 137, width: 36, height: 24)), with: .color(blush))
        ctx.fill(Path(ellipseIn: .init(x: 127, y: 137, width: 36, height: 24)), with: .color(blush))

        // ── 口ひげ（おじさん！）───────────────────────────────────
        ctx.stroke(Path { p in
            p.move(to: .init(x: 80, y: 163))
            p.addQuadCurve(to: .init(x: 100, y: 161), control: .init(x: 91, y: 156))
            p.addQuadCurve(to: .init(x: 120, y: 163), control: .init(x: 109, y: 156))
        }, with: .color(hair), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

        // ── 口（困り顔）──────────────────────────────────────────
        ctx.stroke(Path { p in
            p.move(to: .init(x: 78, y: 173))
            p.addQuadCurve(to: .init(x: 122, y: 173), control: .init(x: 100, y: 183))
        }, with: .color(mouthC), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
    // swiftlint:enable function_body_length
}

#Preview {
    OjisanFaceView()
        .frame(width: 300, height: 330)
        .background(Color.black)
}
