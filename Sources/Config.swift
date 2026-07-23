import Foundation
import Yams

public struct Rule: Codable, Sendable {
    public let name: String?
    public let regex: String
    public let exclude: String?
    public let decision: Decision?
    public let agentic: AgenticMode?

    enum CodingKeys: String, CodingKey {
        case name
        case regex
        case exclude
        case decision
        case agentic
        case agenticMode = "agentic_mode"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.regex = try container.decode(String.self, forKey: .regex)
        self.exclude = try container.decodeIfPresent(String.self, forKey: .exclude)
        self.decision = try container.decodeIfPresent(Decision.self, forKey: .decision)
        
        if let agentic = try container.decodeIfPresent(AgenticMode.self, forKey: .agentic) {
            self.agentic = agentic
        } else if let agenticMode = try container.decodeIfPresent(AgenticMode.self, forKey: .agenticMode) {
            self.agentic = agenticMode
        } else {
            self.agentic = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(regex, forKey: .regex)
        try container.encodeIfPresent(exclude, forKey: .exclude)
        try container.encodeIfPresent(decision, forKey: .decision)
        try container.encodeIfPresent(agentic, forKey: .agentic)
    }

    public init(name: String? = nil, regex: String, exclude: String? = nil, decision: Decision? = nil, agentic: AgenticMode? = nil) {
        self.name = name
        self.regex = regex
        self.exclude = exclude
        self.decision = decision
        self.agentic = agentic
    }
}

public struct GripConfig: Codable, Sendable {
    public let rules: [Rule]
    public let defaultDecision: Decision

    enum CodingKeys: String, CodingKey {
        case rules
        case defaultDecision = "default_decision"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        self.defaultDecision = try container.decodeIfPresent(Decision.self, forKey: .defaultDecision) ?? .ask
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rules, forKey: .rules)
        try container.encode(defaultDecision, forKey: .defaultDecision)
    }

    public init(rules: [Rule], defaultDecision: Decision = .ask) {
        self.rules = rules
        self.defaultDecision = defaultDecision
    }

    public static func load(from customPath: String? = nil) throws -> GripConfig {
        let fileManager = FileManager.default

        if let path = customPath {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let yamlString = String(data: data, encoding: .utf8) ?? ""
            let decoder = YAMLDecoder()
            return try decoder.decode(GripConfig.self, from: yamlString)
        }

        var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath).standardized
        let maxDepth = 20
        var depth = 0

        while depth < maxDepth {
            let candidate = currentDir.appendingPathComponent(".agents/grip.yaml")
            if fileManager.fileExists(atPath: candidate.path) {
                let data = try Data(contentsOf: candidate)
                let yamlString = String(data: data, encoding: .utf8) ?? ""
                let decoder = YAMLDecoder()
                return try decoder.decode(GripConfig.self, from: yamlString)
            }

            let candidateDirect = currentDir.appendingPathComponent("grip.yaml")
            if fileManager.fileExists(atPath: candidateDirect.path) {
                let data = try Data(contentsOf: candidateDirect)
                let yamlString = String(data: data, encoding: .utf8) ?? ""
                let decoder = YAMLDecoder()
                return try decoder.decode(GripConfig.self, from: yamlString)
            }

            let parentDir = currentDir.deletingLastPathComponent().standardized
            if parentDir.path == currentDir.path {
                break
            }
            currentDir = parentDir
            depth += 1
        }

        let homeDir = fileManager.homeDirectoryForCurrentUser
        let globalCandidate = homeDir.appendingPathComponent(".config/grip/grip.yaml")
        if fileManager.fileExists(atPath: globalCandidate.path) {
            let data = try Data(contentsOf: globalCandidate)
            let yamlString = String(data: data, encoding: .utf8) ?? ""
            let decoder = YAMLDecoder()
            return try decoder.decode(GripConfig.self, from: yamlString)
        }

        return GripConfig(rules: [], defaultDecision: .ask)
    }
}
