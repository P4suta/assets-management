import Foundation

enum ContractDates {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo")!
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()
    static let format = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Locale(identifier: "ja_JP"),
                                        calendar: calendar, timeZone: timeZone)
}
