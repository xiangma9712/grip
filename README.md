# grip 🔒

**grip** is a high-performance Swift CLI tool providing advanced, agentic permission control for AI agents (such as Antigravity CLI, Claude Code, Goose, etc.) executing terminal commands.

It evaluates command execution requests against rules defined in `.agents/grip.yaml` via pre-tool execution hooks (`.agents/hooks.json`).

---

## ⚡ Installation & Quick Start

### Download Pre-built Binary via `gh` CLI (Recommended)

You can download the latest release binary directly using GitHub CLI:

```bash
# Download the latest binary release
gh release download --repo xiangma9712/grip --pattern "*.tar.gz"

# Extract and install to /usr/local/bin (or any directory in your PATH)
tar -xzvf grip-macOS-arm64.tar.gz
sudo mv grip /usr/local/bin/
```

### Build from Source

Requirements: macOS 15.0+ with Xcode 16+ & Swift 6.0+

```bash
git clone https://github.com/xiangma9712/grip.git
cd grip
swift build -c release
sudo cp .build/release/grip /usr/local/bin/
```

---

## 🌟 Key Features & Decision Hierarchy

### 1. Multi-layered Evaluation Engine
- **Regex Matcher**: Pattern matching via `regex` field.
- **Exclude Filter**: Exclude specific safe sub-commands using `exclude` field.
- **Deterministic Decisions**: Rule-based immediate decisions (`allow`, `ask`, `deny`).
- **Agentic Decisions**: **Apple Foundation Model** AI evaluation (`allow_read`, `allow_low_risk`).

### 2. Precedence & Decision Hierarchy
1. **Deny-First Precedence (Strictness Priority)**:
   - When multiple rules match a command, the strictest decision is always selected: `deny` > `ask` > `allow`.
2. **Deterministic Over Agentic**:
   - If both deterministic and agentic rules match, **deterministic rules take priority**.
   - Agentic evaluation (Apple Foundation Models) triggers only when no deterministic rule resolves the decision.

---

## 📄 Configuration (`.agents/grip.yaml`)

```yaml
default_decision: ask

rules:
  # 1. Deterministic Deny Rules
  - name: "Block force push to main"
    regex: "^git push (--force|-f) .* (main|master)"
    decision: deny

  # 2. Exclude Filter
  - name: "Deny rm -rf except scratch/tmp"
    regex: "^rm -rf"
    exclude: "^rm -rf (\\./)?(scratch|tmp|\\.build)/"
    decision: deny

  # 3. Deterministic Allow Rules
  - name: "Allow read-only git operations"
    regex: "^git (status|log|diff|show|branch)"
    decision: allow

  # 4. Agentic Decision Rules (Apple Foundation Models)
  - name: "AI Check for read-only status commands"
    regex: "^(cat|ls|pwd|echo|find|grep|rg)"
    agentic: allow_read

  - name: "AI Check for low-risk project scripts"
    regex: "^(npm|yarn|swift|make)"
    agentic: allow_low_risk
```

---

## 🪝 Agent Hook Integration (`.agents/hooks.json`)

Hook `grip` into your agent configuration (`.agents/hooks.json`):

```json
{
  "version": "1.0",
  "hooks": [
    {
      "name": "grip-permission-control",
      "event": "pre_tool_execution",
      "tools": ["run_command", "execute_command", "bash"],
      "command": "grip --json"
    }
  ]
}
```

### JSON Output Standard

When invoked with `--json`, `grip` outputs a standard JSON payload containing human and agent readable messages:

```json
{
  "decision" : "deny",
  "allowed" : false,
  "reason" : "Matched deterministic rule 'Block force push to main'",
  "primaryRule" : "Block force push to main",
  "message" : "🚫 Command execution blocked by grip security policy: Matched deterministic rule 'Block force push to main'"
}
```

---

## 🚀 CLI Usage & Exit Codes

```bash
# Evaluate command passed as argument
grip "git status"

# Output as JSON
grip --json "rm -rf /usr/local"

# Pipe Stdin JSON (Agent hook style)
echo '{"tool": "run_command", "command": "cat README.md"}' | grip --json
```

### Exit Codes
- `0`: **ALLOW**
- `1`: **ASK** (User Confirmation Prompt)
- `2`: **DENY**

---

## 📜 License

[CC0 1.0 Universal (Public Domain Dedication)](LICENSE)
