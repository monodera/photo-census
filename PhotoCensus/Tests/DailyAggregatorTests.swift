import XCTest

final class DailyAggregatorTests: XCTestCase {
    private var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return formatter.date(from: string)!
    }

    private func record(
        _ day: String?,
        isVideo: Bool = false,
        isRAW: Bool = false,
        size: Int64? = 1_000
    ) -> AssetRecord {
        AssetRecord(
            creationDate: day.map { date("\($0) 12:00:00") },
            isVideo: isVideo,
            isRAW: isRAW,
            fileSize: size
        )
    }

    private func stat(for day: String, in result: AggregationResult) -> DailyStat? {
        result.stats.first { $0.day == day }
    }

    func testGroupsByLocalDay() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15"), record("2024-12-15"), record("2024-12-14")],
            photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.stats.count, 2)
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.count, 2)
        XCTAssertEqual(stat(for: "2024-12-14", in: result)?.count, 1)
    }

    func testDailyStatHasStartOfDayDate() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15")], photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.date, date("2024-12-15 00:00:00"))
    }

    func testPhotosOnlyExcludesVideos() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15"), record("2024-12-15", isVideo: true)],
            photosOnly: true, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.totalCount, 1)
    }

    func testRawOnlyKeepsOnlyRaw() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15", isRAW: true), record("2024-12-15"), record("2024-12-14")],
            photosOnly: false, rawOnly: true, calendar: tokyo
        )
        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.count, 1)
        XCTAssertNil(stat(for: "2024-12-14", in: result))
    }

    func testNilDateGroupsAsUnknownWithNilDate() {
        let result = DailyAggregator.aggregate(
            [record(nil)], photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(stat(for: "Unknown", in: result)?.count, 1)
        XCTAssertNil(stat(for: "Unknown", in: result)?.date)
    }

    func testNilSizeCountsAsUnknownAndIsExcludedFromTotals() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15", size: nil), record("2024-12-15", size: 500)],
            photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.unknownSizeCount, 1)
        XCTAssertEqual(result.totalBytes, 500)
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.totalBytes, 500)
    }

    func testTotals() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15", size: 100), record("2024-12-14", size: 200)],
            photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.totalCount, 2)
        XCTAssertEqual(result.totalBytes, 300)
    }

    private let unsorted = [
        DailyStat(day: "Unknown", date: nil, count: 99, totalBytes: 9_999),
        DailyStat(day: "2024-12-14", date: Date(timeIntervalSince1970: 0), count: 3, totalBytes: 300),
        DailyStat(day: "2024-12-15", date: Date(timeIntervalSince1970: 86_400), count: 1, totalBytes: 500),
    ]

    func testSortByDateDescendingUnknownLast() {
        let sorted = DailyAggregator.sorted(unsorted, by: .date, ascending: false)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-15", "2024-12-14", "Unknown"])
    }

    func testSortByDateAscendingUnknownStillLast() {
        let sorted = DailyAggregator.sorted(unsorted, by: .date, ascending: true)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-14", "2024-12-15", "Unknown"])
    }

    func testSortByCountDescending() {
        let sorted = DailyAggregator.sorted(unsorted, by: .count, ascending: false)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-14", "2024-12-15", "Unknown"])
    }

    func testSortBySizeAscending() {
        let sorted = DailyAggregator.sorted(unsorted, by: .size, ascending: true)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-14", "2024-12-15", "Unknown"])
    }
}
