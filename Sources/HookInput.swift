import Foundation

public struct HookInput: Codable, Sendable {
    public let command: String?
    public let tool: String?
    public let toolName: String?
    public let args: [String]?
    public let input: [String: String]?

    enum CodingKeys: String, CodingKey {
        case command
        case tool
        case toolName = "tool_name"
        case args
        case input
    }

    public static func parseStdin() -> String? {
        let fileHandle = FileHandle.standardInput
        guard let data = try? fileHandle.readToEnd(), !data.isEmpty else {
            return nil
        }
        
        // JSON 解釈を試みる
        if let hookInput = try? JSONDecoder().decode(HookInput.self, from: data) {
            if let cmd = hookInput.command, !cmd.isEmpty {
                return cmd
            }
            if let inputCmd = hookInput.input?["command"], !inputCmd.isEmpty {
                return inputCmd
            }
            if let args = hookInput.args, !args.isEmpty {
                return args.joined(separator: " ")
            }
        }

        // Standard String
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        return nil
    }
}

public struct HookOutput: Codable, Sendable {
    public let decision: String
    public let allowed: Bool
    public let reason: String
    public let primaryRule: String?
    public let message: String

    public init(decision: Decision, reason: String, primaryRule: String?, message: String? = nil) {
        self.decision = decision.rawValue
        self.allowed = (decision == .allow)
        self.reason = reason
        self.primaryRule = primaryRule
        
        if let customMsg = message {
            self.message = customMsg
        } else {
            switch decision {
            case .allow:
                self.message = "✅ Command execution allowed by grip permission control."
            case .ask:
                self.message = "❓ Command requires user confirmation: \(reason)"
            case .deny:
                self.message = "🚫 Command execution blocked by grip security policy: \(reason)"
            }
        }
    }
}
