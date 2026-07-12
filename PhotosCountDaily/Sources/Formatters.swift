import Foundation

enum Formatters {
    /// "YYYY-MM-DD"（calendar のタイムゾーン基準）。nil は "Unknown"
    static func dayString(from date: Date?, calendar: Calendar = .current) -> String {
        guard let date else { return "Unknown" }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    /// 10 進単位（KB=1000B、Finder と同一）の人間可読サイズ表記
    static func sizeString(fromBytes bytes: Int64) -> String {
        if bytes < 1000 { return "\(bytes) B" }
        var size = Double(bytes)
        for unit in ["KB", "MB", "GB"] {
            size /= 1000
            // 999.95 以上は "1000.0" と表示されるため次の単位に繰り上げる
            if (size * 10).rounded() / 10 < 1000 {
                return String(format: "%.1f %@", size, unit)
            }
        }
        return String(format: "%.1f TB", size / 1000)
    }
}
