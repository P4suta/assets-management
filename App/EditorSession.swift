import Foundation
import Observation
import PropertyCore

@MainActor @Observable final class EditorFeedback {
    var discard = false
    var saving = false
    var message: String?
}

@MainActor @Observable final class EditorSession<Value: Equatable> {
    var value: Value
    private(set) var baseline: Value
    private(set) var prepared = false
    let feedback = EditorFeedback()

    init(_ value: Value) {
        self.value = value
        baseline = value
    }

    var dirty: Bool { value != baseline }

    func prepare(_ initial: () -> Value) {
        guard !prepared else { return }
        let initial = initial()
        value = initial
        baseline = initial
        prepared = true
    }
}

struct WorkFields: Equatable {
    var item: WorkItem
    var estimate: AmountInput

    init(_ item: WorkItem) {
        self.item = item
        estimate = AmountInput(item.estimate.map(String.init) ?? "")
    }
}

struct ContractFields: Equatable {
    var start: Date
    var end: Date
    var rent = AmountInput()
    var notice: ContractNotice?
}

struct ScheduleFields: Equatable {
    var date: Date
    var enabled = true
    var notify = false
}

struct RenewalFields: Equatable {
    var start: Date
    var end: Date
    var due: Date
    var rent = AmountInput()
    var notify = false
}
