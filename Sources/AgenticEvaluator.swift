import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public actor AgenticEvaluator {
    public static let shared = AgenticEvaluator()

    private init() {}

    /// Apple Foundation Models または セルフチェックにより Agentic Decision を評価する
    public func evaluate(command: String, mode: AgenticMode) async -> Decision {
        print("🤖 [Agentic Evaluation] Evaluating command: '\(command)' with mode: \(mode.rawValue)...")

        #if canImport(FoundationModels)
        if #available(macOS 15.2, *) {
            do {
                let prompt = buildPrompt(command: command, mode: mode)
                let session = LanguageModelSession()
                let response = try await session.generateResponse(for: prompt)
                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                print("🤖 [Apple Foundation Model] Response: \(text)")
                
                if text.contains("allow") || text.contains("yes") || text.contains("safe") {
                    return .allow
                } else if text.contains("deny") || text.contains("no") || text.contains("dangerous") {
                    return .deny
                } else {
                    return .ask
                }
            } catch {
                print("⚠️ [Apple Foundation Model] Error during evaluation: \(error.localizedDescription)")
            }
        }
        #endif

        // OSの FoundationModels API が利用できない場合のヒューリスティックAIフォールバック評価
        return fallbackEvaluation(command: command, mode: mode)
    }

    private func buildPrompt(command: String, mode: AgenticMode) -> String {
        switch mode {
        case .allowRead:
            return """
            You are a security audit AI engine.
            Analyze the following shell command and determine if it is strictly a read-only (information gathering/status check with no side effects) operation.
            Command: `\(command)`

            Answer strictly with 'ALLOW' if it is read-only. Answer 'ASK' if it performs writes, modifications, or network changes.
            """
        case .allowLowRisk:
            return """
            You are a security audit AI engine.
            Analyze the following shell command and determine if it is low-risk and safe to execute automatically.
            Command: `\(command)`

            Answer strictly with 'ALLOW' if it is low-risk. Answer 'ASK' or 'DENY' if it is high-risk, destructive (e.g. deletion, privilege escalation), or modifies system state.
            """
        }
    }

    /// FoundationModels が利用不可・オフライン等の場合のルールベース/セーフティーフォールバック
    private func fallbackEvaluation(command: String, mode: AgenticMode) -> Decision {
        let lower = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch mode {
        case .allowRead:
            // 読み取り専用コマンドの既知パターン判定
            let readOnlyPrefixes = [
                "ls", "cat", "echo", "pwd", "git status", "git log", "git diff",
                "git show", "git branch", "find", "grep", "rg", "head", "tail",
                "wc", "sw_vers", "whoami", "which", "uname", "env"
            ]
            for prefix in readOnlyPrefixes {
                if lower == prefix || lower.hasPrefix(prefix + " ") || lower.hasPrefix(prefix + "\t") {
                    return .allow
                }
            }
            return .ask

        case .allowLowRisk:
            // 低リスクコマンドの既知パターン
            let highRiskKeywords = ["rm ", "rmdir", "sudo", "chmod", "chown", "dd", "mkfs", "curl", "wget", ">", ">>", "kill", "reboot"]
            for keyword in highRiskKeywords {
                if lower.contains(keyword) {
                    return .ask
                }
            }
            return .allow
        }
    }
}
