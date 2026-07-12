import Foundation

enum StatSortField: String, CaseIterable {
    case date
    case count
    case size
}

enum DailyAggregator {
    static func aggregate(
        _ records: [AssetRecord],
        photosOnly: Bool,
        rawOnly: Bool,
        calendar: Calendar = .current
    ) -> AggregationResult {
        var counts: [String: Int] = [:]
        var bytes: [String: Int64] = [:]
        var dayDates: [String: Date] = [:]
        var unknownSizeCount = 0

        for record in records {
            if photosOnly && record.isVideo { continue }
            if rawOnly && !record.isRAW { continue }

            let day = Formatters.dayString(from: record.creationDate, calendar: calendar)
            counts[day, default: 0] += 1
            if let size = record.fileSize {
                bytes[day, default: 0] += size
            } else {
                unknownSizeCount += 1
            }
            if dayDates[day] == nil, let creationDate = record.creationDate {
                dayDates[day] = calendar.startOfDay(for: creationDate)
            }
        }

        let stats = counts.map { day, count in
            DailyStat(day: day, date: dayDates[day], count: count, totalBytes: bytes[day] ?? 0)
        }
        return AggregationResult(
            stats: stats,
            totalCount: stats.reduce(0) { $0 + $1.count },
            totalBytes: stats.reduce(0) { $0 + $1.totalBytes },
            unknownSizeCount: unknownSizeCount
        )
    }

    /// "Unknown" は昇順・降順にかかわらず常に末尾
    static func sorted(
        _ stats: [DailyStat],
        by field: StatSortField,
        ascending: Bool
    ) -> [DailyStat] {
        let known = stats.filter { $0.day != "Unknown" }
        let unknown = stats.filter { $0.day == "Unknown" }
        let sortedKnown: [DailyStat]
        switch field {
        case .date:
            sortedKnown = known.sorted { ascending ? $0.day < $1.day : $0.day > $1.day }
        case .count:
            sortedKnown = known.sorted { ascending ? $0.count < $1.count : $0.count > $1.count }
        case .size:
            sortedKnown = known.sorted { ascending ? $0.totalBytes < $1.totalBytes : $0.totalBytes > $1.totalBytes }
        }
        return sortedKnown + unknown
    }
}
