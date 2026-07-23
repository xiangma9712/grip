import Foundation
import ArgumentParser

@available(macOS 15.0, *)
@main
struct Grip: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "grip",
        abstract: "Advanced Agentic Permission Control CLI Tool for agent command execution.",
        version: "1.0.0"
    )

    @Argument(help: "Command string to evaluate. If omitted, grip reads from stdin.")
    var command: String?

    @Option(name: [.short, .long], help: "Path to custom grip.yaml config file.")
    var config: String?

    @Flag(name: .long, help: "Output decision as JSON format.")
    var json: Bool = false

    @Flag(name: [.short, .long], help: "Verbose output log.")
    var verbose: Bool = false

    func run() async throws {
        // 1. Evaluate target command string
        let targetCommand: String
        if let cmd = command, !cmd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetCommand = cmd
        } else if let stdinCmd = HookInput.parseStdin() {
            targetCommand = stdinCmd
        } else {
            let msg = "Error: No command specified via argument or stdin.\nUsage: grip <command> or pipe JSON/text into grip.\n"
            if let data = msg.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
            throw ExitCode(1)
        }

        // 2. Load Configuration (.agents/grip.yaml)
        let gripConfig: GripConfig
        do {
            gripConfig = try GripConfig.load(from: config)
            if verbose {
                print("📋 Loaded \(gripConfig.rules.count) rules from configuration.")
                for (idx, r) in gripConfig.rules.enumerated() {
                    print("   Rule [#\(idx+1)] name='\(r.name ?? "unnamed")', regex='\(r.regex)', decision=\(String(describing: r.decision)), agentic=\(String(describing: r.agentic))")
                }
            }
        } catch {
            if verbose {
                print("⚠️ [grip] Failed to parse config file: \(error.localizedDescription). Falling back to defaults.")
            }
            gripConfig = GripConfig(rules: [], defaultDecision: .ask)
        }

        // 3. Evaluate Command
        let evaluator = Evaluator()
        let result = await evaluator.evaluate(command: targetCommand, config: gripConfig)

        // 4. Output Results
        if json {
            let output = HookOutput(decision: result.decision, reason: result.reason, primaryRule: result.primaryRuleName)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(output), let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            let symbol: String
            switch result.decision {
            case .allow: symbol = "✅ ALLOW"
            case .ask:   symbol = "❓ ASK"
            case .deny:  symbol = "🚫 DENY"
            }
            print("🔒 [grip] Decision: \(symbol)")
            print("   Command: '\(targetCommand)'")
            print("   Reason: \(result.reason)")
        }

        // 5. Exit with corresponding code
        switch result.decision {
        case .allow:
            throw ExitCode.success
        case .ask:
            throw ExitCode(1)
        case .deny:
            throw ExitCode(2)
        }
    }
}
