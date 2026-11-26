import Testing
import Foundation
@testable import BlackjackTrainer

struct ReminderSchedulerTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func date(_ h: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: h))!
    }

    @Test func beforeSevenGoalUnmetFiresToday() {
        let fire = ReminderScheduler.nextFireDate(now: date(10), goalMet: false, calendar: cal)!
        #expect(cal.component(.day, from: fire) == 10)
        #expect(cal.component(.hour, from: fire) == 19)
    }

    @Test func beforeSevenGoalMetSkipsToTomorrow() {
        let fire = ReminderScheduler.nextFireDate(now: date(10), goalMet: true, calendar: cal)!
        #expect(cal.component(.day, from: fire) == 11)
    }

    @Test func afterSevenFiresTomorrow() {
        let fire = ReminderScheduler.nextFireDate(now: date(21), goalMet: false, calendar: cal)!
        #expect(cal.component(.day, from: fire) == 11)
        #expect(cal.component(.hour, from: fire) == 19)
    }

    @Test func fireDatesCoverSevenConsecutiveSevenPMs() {
        let first = ReminderScheduler.nextFireDate(now: date(10), goalMet: false, calendar: cal)!
        let dates = ReminderScheduler.fireDates(first: first, calendar: cal)
        #expect(dates.count == ReminderScheduler.followUpCount + 1)
        #expect(dates.first == first)
        #expect(dates.allSatisfy { cal.component(.hour, from: $0) == 19 })
        #expect(cal.component(.day, from: dates.last!) == 16)
    }
}
