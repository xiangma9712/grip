import Foundation

public struct EvaluationResult: Sendable {
    public let decision: Decision
    public let matchedRules: [Rule]
    public let primaryRuleName: String?
    public let isDeterministic: Bool
    public let reason: String
}

public struct Evaluator: Sendable {
    public init() {}

    public func evaluate(command: String, config: GripConfig) async -> EvaluationResult {
        // 1. コマンドにマッチする全ルールを抽出
        var matchedRules: [Rule] = []

        for rule in config.rules {
            // Regex matching
            guard let regex = try? NSRegularExpression(pattern: rule.regex, options: []) else {
                continue
            }
            let range = NSRange(location: 0, length: command.utf16.count)
            let isMatch = regex.firstMatch(in: command, options: [], range: range) != nil

            guard isMatch else { continue }

            // Exclude matching check
            if let excludePattern = rule.exclude, !excludePattern.isEmpty {
                if let excludeRegex = try? NSRegularExpression(pattern: excludePattern, options: []) {
                    let excludeMatch = excludeRegex.firstMatch(in: command, options: [], range: range) != nil
                    if excludeMatch {
                        // Excluded, skip this rule
                        continue
                    }
                }
            }

            matchedRules.append(rule)
        }

        if matchedRules.isEmpty {
            return EvaluationResult(
                decision: config.defaultDecision,
                matchedRules: [],
                primaryRuleName: nil,
                isDeterministic: true,
                reason: "No rules matched. Used default decision: \(config.defaultDecision.rawValue)"
            )
        }

        // 2. マッチしたルールを deterministic と agentic に分別
        let deterministicMatchedRules = matchedRules.filter { $0.decision != nil }
        let agenticMatchedRules = matchedRules.filter { $0.agentic != nil }

        // 3. deterministic にも agentic にも match する場合は deterministic 優先
        if !deterministicMatchedRules.isEmpty {
            // 複数の deterministic rule が match する場合はより厳しいもの（deny 優先）
            // strictness order: allow < ask < deny
            var strictnessDecision: Decision = .allow
            var winningRule: Rule? = nil

            for rule in deterministicMatchedRules {
                guard let dec = rule.decision else { continue }
                if dec >= strictnessDecision {
                    strictnessDecision = dec
                    winningRule = rule
                }
            }

            let ruleName = winningRule?.name ?? "Unnamed Rule"
            return EvaluationResult(
                decision: strictnessDecision,
                matchedRules: matchedRules,
                primaryRuleName: ruleName,
                isDeterministic: true,
                reason: "Matched deterministic rule '\(ruleName)' -> \(strictnessDecision.rawValue)"
            )
        }

        // 4. deterministic がなく、agentic のみにマッチした場合
        if !agenticMatchedRules.isEmpty {
            var finalDecision: Decision = .allow
            var evaluatedModes: [String] = []

            for rule in agenticMatchedRules {
                guard let mode = rule.agentic else { continue }
                let result = await AgenticEvaluator.shared.evaluate(command: command, mode: mode)
                evaluatedModes.append("\(rule.name ?? "Rule")(\(mode.rawValue)->\(result.rawValue))")
                
                // より厳しい方を採用
                finalDecision = Decision.mostRestrictive(finalDecision, result)
            }

            let ruleName = agenticMatchedRules.first?.name ?? "Agentic Rule"
            return EvaluationResult(
                decision: finalDecision,
                matchedRules: matchedRules,
                primaryRuleName: ruleName,
                isDeterministic: false,
                reason: "Evaluated agentic rules [\(evaluatedModes.joined(separator: ", "))] -> \(finalDecision.rawValue)"
            )
        }

        return EvaluationResult(
            decision: config.defaultDecision,
            matchedRules: matchedRules,
            primaryRuleName: nil,
            isDeterministic: true,
            reason: "Matched rules had no actionable decision. Used default decision."
        )
    }
}
