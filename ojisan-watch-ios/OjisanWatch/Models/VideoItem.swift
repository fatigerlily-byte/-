import SwiftUI

struct VideoItem: Identifiable {
    let id = UUID()
    let gradientColors: [Color]
    let emoji: String
    let username: String
    let caption: String
    let tags: String
    let likes: String
    let comments: String
    let music: String
}

let videoData: [VideoItem] = [
    VideoItem(
        gradientColors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
        emoji: "🕺", username: "@dance_master_jp",
        caption: "最新ダンスチャレンジ！みんなで踊ろう",
        tags: "#踊ってみた #チャレンジ #TikTok",
        likes: "24.3万", comments: "1.2万", music: "♪ Original Sound - dance_master"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#0f3460"), Color(hex: "#533483")],
        emoji: "🍜", username: "@cooking_girl_tokyo",
        caption: "5分でできる本格ラーメン🍜レシピ公開！",
        tags: "#料理 #時短 #ラーメン",
        likes: "18.7万", comments: "8.9千", music: "♪ Lo-fi Cooking BGM"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#2d1b69"), Color(hex: "#11998e")],
        emoji: "🐱", username: "@neko_life_official",
        caption: "今日も丸くなってる...可愛すぎ問題😂",
        tags: "#猫 #ねこ #かわいい",
        likes: "52.1万", comments: "3.4万", music: "♪ Cat Vibes - neko_life"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#1e3c72"), Color(hex: "#2a5298")],
        emoji: "🎮", username: "@pro_gamer_yuta",
        caption: "このシーン何回見ても鳥肌！神プレイ集",
        tags: "#ゲーム #プロゲーマー #神プレイ",
        likes: "31.5万", comments: "2.1万", music: "♪ Epic Gaming - yuta"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#4a1942"), Color(hex: "#c64f7a")],
        emoji: "💄", username: "@beauty_rena_official",
        caption: "5分メイクで垢抜け！神コスメ紹介",
        tags: "#メイク #コスメ #垢抜け",
        likes: "40.2万", comments: "5.6千", music: "♪ Beauty BGM - rena"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#134e5e"), Color(hex: "#71b280")],
        emoji: "🏋️", username: "@fitness_takuya",
        caption: "毎日10分でここまで変わった！3ヶ月記録",
        tags: "#筋トレ #ダイエット #ビフォーアフター",
        likes: "27.8万", comments: "1.8万", music: "♪ Workout Beat - takuya"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#373b44"), Color(hex: "#4286f4")],
        emoji: "🌆", username: "@travel_japan_hiro",
        caption: "深夜の渋谷がエモすぎる...東京の夜景",
        tags: "#渋谷 #東京 #夜景",
        likes: "15.3万", comments: "7.2千", music: "♪ Night City - hiro"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#ee0979"), Color(hex: "#ff6a00")],
        emoji: "😂", username: "@comedy_shorts_ken",
        caption: "このオチ予想できた人いる？笑",
        tags: "#コメディ #爆笑 #ショート",
        likes: "61.4万", comments: "8.8万", music: "♪ Funny BGM - ken"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#093028"), Color(hex: "#237a57")],
        emoji: "🎸", username: "@music_gen_guitar",
        caption: "路上ライブで100人立ち止まった瞬間",
        tags: "#ギター #路上ライブ #感動",
        likes: "44.7万", comments: "3.3万", music: "♪ Original - gen_guitar"
    ),
    VideoItem(
        gradientColors: [Color(hex: "#360033"), Color(hex: "#0b8793")],
        emoji: "📚", username: "@study_method_ai",
        caption: "東大生が教える「忘れない」暗記術3選",
        tags: "#勉強 #受験 #東大",
        likes: "22.1万", comments: "1.1万", music: "♪ Study BGM - ai"
    ),
]

// MARK: - Color Hex Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}
