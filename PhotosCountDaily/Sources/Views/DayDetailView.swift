import SwiftUI

struct DayDetailView: View {
    let stat: DailyStat
    let photosOnly: Bool
    let rawOnly: Bool

    var body: some View {
        Text("\(stat.day) — \(stat.count) items")
            .padding(40)
    }
}
