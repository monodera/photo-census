import Charts
import SwiftUI

struct ChartView: View {
    var stats: [DailyStat]

    @State private var metric: Metric = .count

    enum Metric: String, CaseIterable {
        case count = "Count"
        case size = "Size"
    }

    /// Unknown（date == nil）はグラフに出せないため除外し、日付昇順で描画する
    private var chartStats: [DailyStat] {
        stats.filter { $0.date != nil }.sorted { $0.day < $1.day }
    }

    /// 全期間を 1 日 6pt で描画する幅。macOS では chartScrollableAxes が
    /// マークを描画しないため、ScrollView + 明示幅でスクロールを実現する
    private var chartWidth: CGFloat {
        guard let first = chartStats.first?.date, let last = chartStats.last?.date else {
            return 600
        }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return max(CGFloat(days + 1) * 6, 600)
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
                ScrollView(.horizontal) {
                    Chart(chartStats) { stat in
                        BarMark(
                            x: .value("Date", stat.date!, unit: .day),
                            y: .value(
                                metric.rawValue,
                                metric == .count ? Double(stat.count) : Double(stat.totalBytes)
                            )
                        )
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
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
                    .frame(width: chartWidth, height: geometry.size.height)
                }
                .defaultScrollAnchor(.trailing)
            }
            .padding([.horizontal, .bottom])
        }
    }
}
