import XCTest

final class FormattersTests: XCTestCase {
    private var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ string: String, timeZone: String = "Asia/Tokyo") -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: timeZone)!
        return formatter.date(from: string)!
    }

    func testDayStringFormatsLocalDay() {
        XCTAssertEqual(Formatters.dayString(from: date("2024-12-15 09:30:00"), calendar: tokyo), "2024-12-15")
    }

    func testDayStringUsesCalendarTimeZone() {
        // UTC 2024-12-15 23:30 = 東京では 2024-12-16 08:30 → calendar のタイムゾーンで日付が決まる
        XCTAssertEqual(
            Formatters.dayString(from: date("2024-12-15 23:30:00", timeZone: "UTC"), calendar: tokyo),
            "2024-12-16"
        )
    }

    func testDayStringNilIsUnknown() {
        XCTAssertEqual(Formatters.dayString(from: nil, calendar: tokyo), "Unknown")
    }

    func testSizeStringBytes() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 999), "999 B")
    }

    func testSizeStringKB() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 1000), "1.0 KB")
    }

    func testSizeStringMB() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 980_500_000), "980.5 MB")
    }

    func testSizeStringGB() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 2_100_000_000), "2.1 GB")
    }

    func testSizeStringRollsOverNearUnitBoundary() {
        // 999.96 MB は "1000.0 MB" と表示されてしまうため GB に繰り上げる
        XCTAssertEqual(Formatters.sizeString(fromBytes: 999_960_000), "1.0 GB")
    }
}
