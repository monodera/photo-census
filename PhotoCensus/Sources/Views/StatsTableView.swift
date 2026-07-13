import SwiftUI

struct StatsTableView: View {
    @Bindable var viewModel: LibraryStatsViewModel
    @Binding var selection: DailyStat.ID?
    @Binding var selectedDay: DailyStat?

    @State private var sortOrder = [KeyPathComparator(\DailyStat.count, order: .reverse)]
    @State private var hoveredID: DailyStat.ID?
    @State private var tableWidth: CGFloat = 0

    var body: some View {
        Table(viewModel.sortedStats, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.day) { stat in
                Text(stat.day)
                    .rowHoverBackground(stat.id, hoveredID: $hoveredID, rowWidth: tableWidth)
            }
            TableColumn("Count", value: \.count) { stat in
                Text("\(stat.count)")
                    .rowHoverDetector(stat.id, hoveredID: $hoveredID)
            }
            .width(min: 60, ideal: 80)
            TableColumn("Size", value: \.totalBytes) { stat in
                Text(Formatters.sizeString(fromBytes: stat.totalBytes))
                    .rowHoverDetector(stat.id, hoveredID: $hoveredID)
            }
            .width(min: 80, ideal: 110)
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { tableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newValue in tableWidth = newValue }
            }
        )
        .onChange(of: sortOrder) { _, newOrder in
            guard let first = newOrder.first else { return }
            viewModel.sortAscending = first.order == .forward
            switch first.keyPath {
            case \DailyStat.day:
                viewModel.sortField = .date
            case \DailyStat.count:
                viewModel.sortField = .count
            case \DailyStat.totalBytes:
                viewModel.sortField = .size
            default:
                break
            }
        }
        .onChange(of: selection) { _, id in
            // Unknown 行（date == nil）は詳細表示できないので開かない
            selectedDay = viewModel.sortedStats.first { $0.id == id && $0.date != nil }
        }
    }
}

private extension View {
    /// hover の検出だけを行う（背景は先頭列側でまとめて描くため塗らない）
    func rowHoverDetector(_ id: DailyStat.ID, hoveredID: Binding<DailyStat.ID?>) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { hovering in
                hoveredID.wrappedValue = hovering ? id : (hoveredID.wrappedValue == id ? nil : hoveredID.wrappedValue)
            }
    }

    /// 行全体のハイライト背景。Table は列ごとに別々のセルとして描画され、
    /// 列間には隙間があるため個々のセルの frame ぴったりに塗ると隙間が残る
    /// （隙間の推測値で塗るのも二重塗り／塗り残しの原因になり不安定）。
    /// 先頭列のセルから実測したテーブル全幅ぶんの矩形をはみ出させて描画する
    /// ことで、隙間を推測せずに行全体を継ぎ目なく塗る
    func rowHoverBackground(_ id: DailyStat.ID, hoveredID: Binding<DailyStat.ID?>, rowWidth: CGFloat) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(alignment: .leading) {
                (hoveredID.wrappedValue == id ? Color.accentColor.opacity(0.15) : Color.clear)
                    .frame(width: rowWidth, alignment: .leading)
                    .allowsHitTesting(false)
            }
            .onHover { hovering in
                hoveredID.wrappedValue = hovering ? id : (hoveredID.wrappedValue == id ? nil : hoveredID.wrappedValue)
            }
    }
}
