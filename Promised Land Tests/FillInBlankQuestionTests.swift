import Foundation
import Testing
@testable import Promised_Land

@MainActor
struct FillInBlankQuestionTests {
    @Test("A chip drop accepts the blank and its 24-point margin")
    func dropZoneIncludesExpandedBlank() {
        let blank = CGRect(x: 100, y: 200, width: 80, height: 44)

        #expect(FillInBlankQuestionView.isDropLocation(CGPoint(x: 100, y: 200), in: blank))
        #expect(FillInBlankQuestionView.isDropLocation(CGPoint(x: 76, y: 222), in: blank))
    }

    @Test("A chip drop just outside the 24-point margin is rejected")
    func dropZoneRejectsJustOutsideMargin() {
        let blank = CGRect(x: 100, y: 200, width: 80, height: 44)

        #expect(!FillInBlankQuestionView.isDropLocation(CGPoint(x: 75.99, y: 222), in: blank))
    }

    @Test("A chip drop far from the blank is rejected")
    func dropZoneRejectsFarAwayLocation() {
        let blank = CGRect(x: 100, y: 200, width: 80, height: 44)

        #expect(!FillInBlankQuestionView.isDropLocation(CGPoint(x: 20, y: 20), in: blank))
    }
}
