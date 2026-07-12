import Charts
import SwiftUI

private struct ChartScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ChartView: View {
    var stats: [DailyStat]
    @Binding var selectedDay: DailyStat?

    @State private var metric: Metric = .count
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var hovered: HoverInfo?

    enum Metric: String, CaseIterable {
        case count = "Count"
        case size = "Size"
    }

    struct HoverInfo: Equatable {
        var stat: DailyStat
        var location: CGPoint
    }

    private let pointsPerDay: CGFloat = 6
    private let axisWidth: CGFloat = 64

    /// Unknown（date == nil）はグラフに出せないため除外し、日付昇順で描画する
    private var chartStats: [DailyStat] {
        stats.filter { $0.date != nil }.sorted { $0.day < $1.day }
    }

    /// ホバー・クリック時の日付→統計の逆引き（キーは各日の 00:00）
    private var statsByDay: [Date: DailyStat] {
        Dictionary(uniqueKeysWithValues: chartStats.compactMap { stat in
            stat.date.map { ($0, stat) }
        })
    }

    /// 全期間を 1 日 6pt で描画する幅。macOS では chartScrollableAxes が
    /// マークを描画しないため、ScrollView + 明示幅でスクロールを実現する
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
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .padding(.top, 8)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ScrollView(.horizontal) {
                        scrollingChart
                            .frame(width: chartWidth, height: geometry.size.height)
                            .background(
                                GeometryReader { inner in
                                    Color.clear.preference(
                                        key: ChartScrollOffsetKey.self,
                                        value: -inner.frame(in: .named("chartScroll")).minX
                                    )
                                }
                            )
                    }
                    .coordinateSpace(name: "chartScroll")
                    .defaultScrollAnchor(.trailing)
                    .onPreferenceChange(ChartScrollOffsetKey.self) { offset in
                        scrollOffset = offset
                    }

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

    /// スクロールする本体。y 軸ラベルは出さずグリッド線のみ（ラベルは axisChart に固定表示）
    private var scrollingChart: some View {
        Chart(chartStats) { stat in
            BarMark(
                x: .value("Date", stat.date!, unit: .day),
                y: .value(metric.rawValue, value(of: stat))
            )
            .opacity(hovered?.stat.id == stat.id ? 1.0 : 0.75)
        }
        .chartYScale(domain: 0...visibleYMax)
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hovered = hoverInfo(at: location, proxy: proxy, geo: geo)
                        case .ended:
                            hovered = nil
                        }
                    }
                    .onTapGesture { location in
                        if let info = hoverInfo(at: location, proxy: proxy, geo: geo) {
                            selectedDay = info.stat
                        }
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            tooltip
        }
    }

    /// スクロールしても位置が変わらない y 軸ラベル。マークは不可視の RuleMark のみ
    private var axisChart: some View {
        Chart {
            RuleMark(y: .value("Value", 0)).opacity(0)
        }
        .chartYScale(domain: 0...visibleYMax)
        .chartXAxis(.hidden)
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

    private func hoverInfo(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) -> HoverInfo? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let origin = geo[plotFrame].origin
        let x = location.x - origin.x
        guard let date: Date = proxy.value(atX: x) else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        guard let stat = statsByDay[day] else { return nil }
        return HoverInfo(stat: stat, location: location)
    }
}
