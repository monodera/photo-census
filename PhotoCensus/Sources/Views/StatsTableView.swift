import SwiftUI

struct StatsTableView: View {
    @Bindable var viewModel: LibraryStatsViewModel
    @Binding var selection: DailyStat.ID?
    @Binding var selectedDay: DailyStat?

    @State private var sortOrder = [KeyPathComparator(\DailyStat.count, order: .reverse)]

    var body: some View {
        Table(viewModel.sortedStats, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.day)
            TableColumn("Count", value: \.count) { stat in
                Text("\(stat.count)")
            }
            .width(min: 60, ideal: 80)
            TableColumn("Size", value: \.totalBytes) { stat in
                Text(Formatters.sizeString(fromBytes: stat.totalBytes))
            }
            .width(min: 80, ideal: 110)
        }
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
