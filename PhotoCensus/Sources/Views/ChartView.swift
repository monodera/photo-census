import AppKit
import Charts
import SwiftUI

/// NSScrollView のスクロール位置を（慣性スクロール含めて）デバウンス付きで通知する。
/// PreferenceKey ベースの手法は macOS の ScrollView ではスクロール中に
/// 更新が発火しないため、NSScrollView を直接観測する。
private struct ScrollOffsetReader: NSViewRepresentable {
    var onSettle: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                context.coordinator.observe(scrollView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSettle = onSettle
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSettle: onSettle)
    }

    final class Coordinator {
        var onSettle: (CGFloat) -> Void
        private var token: NSObjectProtocol?
        private var pending: DispatchWorkItem?
        private weak var clipView: NSClipView?

        init(onSettle: @escaping (CGFloat) -> Void) {
            self.onSettle = onSettle
        }

        func observe(_ scrollView: NSScrollView) {
            guard token == nil else { return }
            let clip = scrollView.contentView
            clipView = clip
            clip.postsBoundsChangedNotifications = true
            token = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clip,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleReport()
            }
            report()
        }

        private func scheduleReport() {
            pending?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.report() }
            pending = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }

        private func report() {
            guard let clip = clipView else { return }
            onSettle(clip.bounds.origin.x)
        }

        deinit {
            pending?.cancel()
            if let token {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}

struct ChartView: View {
    @Binding private var selectedDay: DailyStat?

    @State private var metric: Metric = .count
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    /// Unknown（date == nil）を除外した日付昇順の統計と、日付 00:00 → 統計の逆引き。
    /// body 評価のたびに再計算しないよう init で一度だけ作る
    private let chartStats: [DailyStat]
    private let statsByDay: [Date: DailyStat]

    enum Metric: String, CaseIterable {
        case count = "Count"
        case size = "Size"
    }

    private let pointsPerDay: CGFloat = 12
    private let axisWidth: CGFloat = 64

    init(stats: [DailyStat], selectedDay: Binding<DailyStat?>) {
        let filtered = stats.filter { $0.date != nil }.sorted { $0.day < $1.day }
        chartStats = filtered
        statsByDay = Dictionary(uniqueKeysWithValues: filtered.compactMap { stat in
            stat.date.map { ($0, stat) }
        })
        _selectedDay = selectedDay
    }

    private var chartWidth: CGFloat {
        guard let first = chartStats.first?.date, let last = chartStats.last?.date else {
            return 600
        }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return max(CGFloat(days + 1) * pointsPerDay, 600)
    }

    /// スクロールで見えている期間内の最大値から y 軸の上限を決める
    private var visibleYMax: Double {
        guard let first = chartStats.first?.date else { return 1 }
        let calendar = Calendar.current
        let startDays = Int(scrollOffset / pointsPerDay) - 1
        let endDays = Int((scrollOffset + viewportWidth) / pointsPerDay) + 1
        guard let startDate = calendar.date(byAdding: .day, value: startDays, to: first),
              let endDate = calendar.date(byAdding: .day, value: endDays, to: first) else {
            return 1
        }
        let maxValue = chartStats
            .filter { stat in
                guard let date = stat.date else { return false }
                return date >= startDate && date <= endDate
            }
            .map { value(of: $0) }
            .max() ?? 0
        return max(maxValue * 1.05, 1)
    }

    private func value(of stat: DailyStat) -> Double {
        metric == .count ? Double(stat.count) : Double(stat.totalBytes)
    }

    var body: some View {
        VStack(spacing: 8) {
            SlidingSegmentedControl(options: Metric.allCases, selection: $metric) { metric in
                metric.rawValue
            }
            .padding(.top, 8)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ScrollView(.horizontal) {
                        scrollingChart
                            .frame(width: chartWidth, height: geometry.size.height)
                            .background(
                                ScrollOffsetReader { offset in
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        scrollOffset = offset
                                    }
                                }
                            )
                    }
                    .defaultScrollAnchor(.trailing)

                    axisChart
                        .frame(width: axisWidth, height: geometry.size.height)
                }
                .onChange(of: geometry.size.width, initial: true) { _, width in
                    viewportWidth = max(width - axisWidth, 0)
                }
            }
            .padding([.horizontal, .bottom])
        }
    }

    /// スクロールする本体。y 軸ラベルは axisChart に固定表示するためグリッド線のみ
    private var scrollingChart: some View {
        Chart(chartStats) { stat in
            BarMark(
                x: .value("Date", stat.date!, unit: .day),
                y: .value(metric.rawValue, value(of: stat)),
                width: .fixed(9)
            )
        }
        .chartYScale(domain: 0...visibleYMax)
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.year().month(.abbreviated))
            }
        }
        .chartOverlay { proxy in
            ChartInteractionOverlay(
                statsByDay: statsByDay,
                chartWidth: chartWidth,
                proxy: proxy,
                selectedDay: $selectedDay
            )
        }
    }

    /// スクロールしても位置が変わらない y 軸ラベル。マークは不可視の RuleMark のみ
    private var axisChart: some View {
        Chart {
            RuleMark(y: .value("Value", 0)).opacity(0)
        }
        .chartYScale(domain: 0...visibleYMax)
        .chartXAxis(.hidden)
        .chartYAxisLabel(position: .top, alignment: .leading) {
            if metric == .count {
                Text("items")
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        if metric == .size {
                            Text(Formatters.sizeString(fromBytes: Int64(raw)))
                        } else {
                            Text("\(Int(raw))")
                        }
                    }
                }
            }
        }
    }
}

/// ホバー・クリックの処理とツールチップ描画。hover 状態をこのビューに閉じ込め、
/// マウス移動のたびに数千本の BarMark を再評価しないようにする
private struct ChartInteractionOverlay: View {
    let statsByDay: [Date: DailyStat]
    let chartWidth: CGFloat
    let proxy: ChartProxy
    @Binding var selectedDay: DailyStat?

    @State private var hovered: HoverInfo?

    struct HoverInfo: Equatable {
        var stat: DailyStat
        var location: CGPoint
    }

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hovered = hoverInfo(at: location, geo: geo)
                    case .ended:
                        hovered = nil
                    }
                }
                .onTapGesture { location in
                    if let info = hoverInfo(at: location, geo: geo) {
                        selectedDay = info.stat
                    }
                }
                .overlay(alignment: .topLeading) {
                    tooltip
                }
        }
    }

    @ViewBuilder private var tooltip: some View {
        if let hovered {
            VStack(alignment: .leading, spacing: 2) {
                Text(hovered.stat.day)
                    .font(.caption.bold())
                Text("\(hovered.stat.count) items")
                    .font(.caption)
                Text(Formatters.sizeString(fromBytes: hovered.stat.totalBytes))
                    .font(.caption)
            }
            .padding(6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .offset(
                x: max(min(hovered.location.x + 12, chartWidth - 150), 0),
                y: max(hovered.location.y - 64, 4)
            )
            .allowsHitTesting(false)
        }
    }

    private func hoverInfo(at location: CGPoint, geo: GeometryProxy) -> HoverInfo? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let origin = geo[plotFrame].origin
        let x = location.x - origin.x
        guard let date: Date = proxy.value(atX: x) else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        guard let stat = statsByDay[day] else { return nil }
        return HoverInfo(stat: stat, location: location)
    }
}
