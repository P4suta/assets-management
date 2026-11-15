import Foundation
import PropertyCore
import Testing
@testable import PropertyRecords

@Suite @MainActor struct EditorSessionTests {
    @Test func preparationCannotReplaceAnEditedDraftOrItsBaseline() {
        let session = EditorSession(RegistrationDraft())
        let initial = RegistrationDraft(name: "建物", roomNumber: "101")
        session.prepare { initial }
        #expect(!session.dirty)
        session.value.name = "編集した建物"
        session.feedback.message = "Retry the save."
        session.feedback.saving = true
        session.feedback.discard = true
        session.prepare { Issue.record("An existing session must not reload its draft."); return RegistrationDraft() }
        #expect(session.value.name == "編集した建物")
        #expect(session.baseline == initial)
        #expect(session.dirty)
        #expect(session.feedback.message == "Retry the save.")
        #expect(session.feedback.saving)
        #expect(session.feedback.discard)
    }

    @Test func rejectedAmountsStayRejectedAcrossPreparation() {
        let date = Date(timeIntervalSince1970: 1_794_445_200)
        let session = EditorSession(ContractFields(start: date, end: date, rent: AmountInput("82000")))
        session.prepare { session.value }
        session.value.rent.replace(with: String(repeating: "9", count: 1000))
        session.prepare { ContractFields(start: date, end: date) }
        #expect(session.value.rent.text == "82000")
        #expect(session.value.rent.issue == .tooLong)
        #expect(!session.value.rent.isValid)
        #expect(session.dirty)
        session.value.rent.clear()
        #expect(session.value.rent.isValid)
        #expect(session.dirty)
    }

    @Test func scheduleAndRenewalFieldsKeepAllChanges() {
        let date = Date(timeIntervalSince1970: 1_794_445_200)
        let schedule = EditorSession(ScheduleFields(date: date))
        schedule.prepare { schedule.value }
        schedule.value.date = date.addingTimeInterval(3600)
        schedule.value.enabled = false
        schedule.value.notify = true
        let changedSchedule = schedule.value
        schedule.prepare { ScheduleFields(date: date) }
        #expect(schedule.value == changedSchedule)
        #expect(schedule.dirty)
        let renewal = EditorSession(RenewalFields(start: date, end: date, due: date))
        renewal.prepare { renewal.value }
        renewal.value.start = date.addingTimeInterval(86_400)
        renewal.value.end = date.addingTimeInterval(172_800)
        renewal.value.due = date.addingTimeInterval(3600)
        renewal.value.rent.replace(with: "88000")
        renewal.value.notify = true
        let changedRenewal = renewal.value
        renewal.prepare { RenewalFields(start: date, end: date, due: date) }
        #expect(renewal.value == changedRenewal)
        #expect(renewal.dirty)
    }

    @Test func presentationsHaveIndependentIdentitiesAndReleaseDiscardedDrafts() throws {
        var destination: EditorDestination? = .registration
        weak var discarded: EditorSession<RegistrationDraft>?
        let other = EditorDestination.registration
        do {
            let destination = try #require(destination)
            #expect(destination.id != other.id)
            guard case .registration(let session) = destination.content else { Issue.record("Registration session missing."); return }
            discarded = session
            session.value.name = "未保存"
        }
        guard case .registration(let otherSession) = other.content else { Issue.record("Registration session missing."); return }
        #expect(otherSession.value == RegistrationDraft())
        #expect(!otherSession.dirty)
        #expect(discarded?.value.name == "未保存")
        destination = nil
        #expect(discarded == nil)
    }
}
