import SwiftUI

struct ContentView: View {
    @State private var viewModel = LibraryStatsViewModel()
    @State private var display: DisplayMode = .table
    @State private var tableSelection: DailyStat.ID?
    @State private var selectedDay: DailyStat?

    enum DisplayMode: String, CaseIterable {
        case table = "Table"
        case chart = "Chart"
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ProgressView("Requesting Photos access…")
            case .denied:
                AccessDeniedView()
            case .loading(let done, let total):
                VStack(spacing: 12) {
                    if total > 0 {
                        ProgressView(value: Double(done), total: Double(total))
                            .frame(maxWidth: 300)
                        Text("Scanning \(done) / \(total) items…")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView("Loading Photos library…")
                    }
                }
            case .loaded:
                loadedView
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .task { await viewModel.load() }
    }

    private var loadedView: some View {
        VStack(spacing: 0) {
            switch display {
            case .table:
                StatsTableView(
                    viewModel: viewModel,
                    selection: $tableSelection,
                    selectedDay: $selectedDay
                )
            case .chart:
                ChartView(stats: viewModel.sortedStats, selectedDay: $selectedDay)
            }
            Divider()
            summaryBar
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(MediaFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                Picker("Display", selection: $display) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .sheet(item: $selectedDay, onDismiss: { tableSelection = nil }) { day in
            DayDetailView(
                stat: day,
                photosOnly: viewModel.filter == .photosOnly,
                rawOnly: viewModel.filter == .rawOnly
            )
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 8) {
            Text("Total: \(viewModel.result.totalCount) items, \(Formatters.sizeString(fromBytes: viewModel.result.totalBytes)) across \(viewModel.result.stats.count) days")
            if viewModel.result.unknownSizeCount > 0 {
                Text("(\(viewModel.result.unknownSizeCount) items with unknown size)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.callout)
        .padding(8)
    }
}
