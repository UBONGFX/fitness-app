import Testing
@testable import FitnessApp

struct GoalDraftTests {
    @Test func disabledGoalHasNoTarget() {
        #expect(GoalDraft(isEnabled: false, lower: 80, upper: 82).target == nil)
    }

    @Test func oneValueCreatesSingleValueTarget() {
        let target = GoalDraft(isEnabled: true, upper: 82).target
        #expect(target?.lower == 82)
        #expect(target?.upper == 82)
    }

    @Test func twoValuesCreateAnOrderedRange() {
        let target = GoalDraft(isEnabled: true, lower: 82, upper: 80).target
        #expect(target?.lower == 80)
        #expect(target?.upper == 82)
    }

    @Test func enabledGoalNeedsAPositiveValue() {
        #expect(GoalDraft(isEnabled: true).target == nil)
        #expect(GoalDraft(isEnabled: true, lower: 0).target == nil)
    }
}
