import Foundation

/// Deterministic Decision
public enum Decision: String, Codable, Equatable, Comparable, Sendable {
    case allow
    case ask
    case deny

    /// 厳しさの優先順位 (Strictness Order: allow < ask < deny)
    private var strictnessRank: Int {
        switch self {
        case .allow: return 0
        case .ask:   return 1
        case .deny:  return 2
        }
    }

    public static func < (lhs: Decision, rhs: Decision) -> Bool {
        return lhs.strictnessRank < rhs.strictnessRank
    }

    /// 2つの Decision のうち、より厳しい（Restrictive）ものを返す
    public static func mostRestrictive(_ lhs: Decision, _ rhs: Decision) -> Decision {
        return lhs > rhs ? lhs : rhs
    }
}

/// Agentic Decision Mode
public enum AgenticMode: String, Codable, Equatable, Sendable {
    case allowRead = "allow_read"
    case allowLowRisk = "allow_low_risk"
}
