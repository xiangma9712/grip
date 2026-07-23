import Testing
import Foundation
@testable import grip

struct GripTests {

    @Test func testDeterministicPrecedenceAndDenyPriority() async throws {
        let config = GripConfig(rules: [
            Rule(name: "Allow git", regex: "^git ", decision: .allow),
            Rule(name: "Deny destructive git push force", regex: "^git push --force", decision: .deny),
            Rule(name: "Ask for git push", regex: "^git push", decision: .ask)
        ])

        let evaluator = Evaluator()

        // 1. "git status" -> Should match "Allow git" -> .allow
        let res1 = await evaluator.evaluate(command: "git status", config: config)
        #expect(res1.decision == .allow)

        // 2. "git push origin main" -> Matches "Allow git" (.allow) and "Ask for git push" (.ask) -> Should choose stricter .ask
        let res2 = await evaluator.evaluate(command: "git push origin main", config: config)
        #expect(res2.decision == .ask)

        // 3. "git push --force origin main" -> Matches .allow, .ask, and .deny -> Should choose strictest .deny
        let res3 = await evaluator.evaluate(command: "git push --force origin main", config: config)
        #expect(res3.decision == .deny)
    }

    @Test func testExcludeRule() async throws {
        let config = GripConfig(rules: [
            Rule(name: "Deny rm -rf", regex: "^rm -rf", exclude: "^rm -rf /tmp/", decision: .deny)
        ])

        let evaluator = Evaluator()

        // "rm -rf /important" -> Matches regex, no exclude -> .deny
        let res1 = await evaluator.evaluate(command: "rm -rf /important", config: config)
        #expect(res1.decision == .deny)

        // "rm -rf /tmp/scratch" -> Excluded -> No match -> default decision .ask
        let res2 = await evaluator.evaluate(command: "rm -rf /tmp/scratch", config: config)
        #expect(res2.decision == .ask)
    }

    @Test func testDeterministicOverAgenticPriority() async throws {
        let config = GripConfig(rules: [
            Rule(name: "Deterministic Allow echo", regex: "^echo ", decision: .allow),
            Rule(name: "Agentic Allow Read echo", regex: "^echo ", agentic: .allowRead)
        ])

        let evaluator = Evaluator()

        // Both deterministic and agentic match -> Deterministic takes priority!
        let res = await evaluator.evaluate(command: "echo Hello", config: config)
        #expect(res.decision == .allow)
        #expect(res.isDeterministic == true)
        #expect(res.primaryRuleName == "Deterministic Allow echo")
    }

    @Test func testAgenticFallbackEvaluation() async throws {
        let config = GripConfig(rules: [
            Rule(name: "AI Read check", regex: "^git ", agentic: .allowRead)
        ])

        let evaluator = Evaluator()

        // "git status" is read-only -> .allow
        let res1 = await evaluator.evaluate(command: "git status", config: config)
        #expect(res1.decision == .allow)
    }
}
