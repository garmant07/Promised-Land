import Testing
import Foundation
@testable import Promised_Land

@MainActor
struct RevealTests {
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func island(_ reads: [(String, Int)]) -> (Island, [String: [Int]]) {
        let dated = reads.enumerated().map { ($1.0, $1.1, start.addingTimeInterval(Double($0) * 60)) }
        var order: [String: [Int]] = [:]
        for (b, c) in reads where !(order[b]?.contains(c) ?? false) { order[b, default: []].append(c) }
        return (Island.build(chapters: dated, quizzes: [], verses: []), order)
    }

    @Test("One chapter: one beat naming the chapter and what it built, with the Place's progress")
    func single() {
        let (i, order) = island([("ruth", 1), ("ruth", 2)])
        let plan = RevealPlanner.plan(island: i, before: ["ruth": 1], chapterOrder: order)
        #expect(plan.steps.count == 1)
        let step = plan.steps[0]
        #expect(step.caption == "Ruth 2: the barn is built")
        #expect(step.progressLabel == "The Farmstead · 2 of 4 chapters")
        #expect(step.kind == .grow)
        // The barn starts hidden and pops up.
        #expect(step.changes.contains { $0.index == step.focus && $0.from == 0 && $0.to == 1 })
        #expect(plan.initial[step.focus] == 0)
    }

    @Test("Founding and completing are bigger moments")
    func bigMoments() {
        let (i, order) = island([("ruth", 1)])
        #expect(RevealPlanner.plan(island: i, before: [:], chapterOrder: order).steps.first?.kind == .found)
        let (done, o2) = island((1...4).map { ("ruth", $0) })
        let last = RevealPlanner.plan(island: done, before: ["ruth": 3], chapterOrder: o2).steps.first
        #expect(last?.kind == .complete)
        #expect((last?.duration ?? 0) > 2.8)
    }

    @Test("Up to three chapters play in sequence; more play as one combined reveal")
    func sequenceOrCombined() {
        let (i, order) = island((1...10).map { ("genesis", $0) })
        let three = RevealPlanner.plan(island: i, before: ["genesis": 7], chapterOrder: order)
        #expect(three.steps.count == 3)
        #expect(three.steps.map(\.caption).allSatisfy { $0.hasPrefix("Genesis") })
        let many = RevealPlanner.plan(island: i, before: ["genesis": 2], chapterOrder: order)
        #expect(many.steps.count == 1 && many.steps[0].kind == .combined)
        #expect(many.steps[0].caption.hasPrefix("8 chapters built"))
    }

    @Test("A growing field spreads from its old size, and nothing old changes")
    func spreads() {
        let (i, order) = island((1...12).map { ("psalms", $0) })
        let plan = RevealPlanner.plan(island: i, before: ["psalms": 11], chapterOrder: order)
        let change = plan.steps[0].changes
        #expect(!change.isEmpty)
        #expect(change.allSatisfy { $0.to > $0.from })
        #expect(RevealPlanner.plan(island: i, before: ["psalms": 12], chapterOrder: order).steps.isEmpty)
    }
}
