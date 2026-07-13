import Foundation

/// PhotoKit 資産の中間表現。集計ロジックを PhotoKit から切り離すための純粋データ。
struct AssetRecord: Equatable {
    var creationDate: Date?
    var isVideo: Bool
    var isRAW: Bool
    /// nil はサイズ不明（iCloud 未ダウンロード等でリソースからサイズが取れない場合）
    var fileSize: Int64?
}

struct DailyStat: Identifiable, Equatable {
    /// "YYYY-MM-DD" または "Unknown"
    var day: String
    /// その日の 00:00（ローカルタイムゾーン）。Unknown は nil。グラフの x 軸に使う
    var date: Date?
    var count: Int
    var totalBytes: Int64
    var id: String { day }
}

struct AggregationResult: Equatable {
    var stats: [DailyStat]
    var totalCount: Int
    var totalBytes: Int64
    /// fileSize が nil だった（合計に含められなかった）資産数
    var unknownSizeCount: Int

    static let empty = AggregationResult(stats: [], totalCount: 0, totalBytes: 0, unknownSizeCount: 0)
}
