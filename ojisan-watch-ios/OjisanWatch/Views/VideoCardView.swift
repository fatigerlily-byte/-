import SwiftUI

/// TikTok 風の1動画カード
struct VideoCardView: View {
    let video: VideoItem

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景グラデーション
                LinearGradient(colors: video.gradientColors,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                // 大きい絵文字（背景装飾）
                Text(video.emoji)
                    .font(.system(size: 160))
                    .opacity(0.12)

                // 右側アクションボタン
                VStack(spacing: 24) {
                    actionButton("heart.fill",       label: video.likes,    color: .white)
                    actionButton("bubble.right.fill", label: video.comments, color: .white)
                    actionButton("arrowshape.turn.up.right.fill", label: "シェア", color: .white)
                    actionButton("ellipsis",          label: "",             color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 12)
                .padding(.bottom, 100)

                // 下部テキスト情報
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.username)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text(video.caption)
                        .font(.system(size: 13))
                        .foregroundColor(.white)

                    Text(video.tags)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#69c0ff"))

                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11))
                        Text(video.music)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: geo.size.width * 0.75, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 16)
                .padding(.bottom, 80)

                // 動画プログレスバー（ダミー）
                ProgressView(value: 0.4)
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 62)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .shadow(color: .black.opacity(0.3), radius: 4)
    }

    private func actionButton(_ icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
            }
        }
    }
}
