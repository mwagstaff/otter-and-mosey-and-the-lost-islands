import Testing
@testable import LostIslandsCore

@Suite struct KeyboardCapitalizationTests {
    @Test func namesCapitalizeEachPartAndResetAfterDeletion() {
        for prefix in ["", "Nova ", "Anne-", " "] {
            #expect(KeyboardCapitalization.name(after: prefix))
        }
        for prefix in ["N", "Nova", "Anne-M", "O’"] {
            #expect(!KeyboardCapitalization.name(after: prefix))
        }
        var name = "N"
        name.removeLast()
        #expect(KeyboardCapitalization.name(after: name))
    }

    @Test func exercisesFollowSentenceStartsAndProperNames() {
        let target = "Hi Nova. I am Otter"
        let uppercase = target.indices.enumerated().compactMap { index, _ in
            KeyboardCapitalization.target(target, at: index) ? index : nil
        }
        #expect(uppercase == [0, 3, 9, 14])
        #expect(!KeyboardCapitalization.target(target, at: -1))
        #expect(!KeyboardCapitalization.target(target, at: target.count))
    }

    @Test func missingLettersAndNumberAnswersStayUnshifted() {
        for target in ["sun", "u", "42", " ", ""] {
            #expect(!KeyboardCapitalization.target(target, at: 0))
        }
        #expect(KeyboardCapitalization.target("Élan", at: 0))
        #expect(!KeyboardCapitalization.target("Élan", at: 1))
    }
}
