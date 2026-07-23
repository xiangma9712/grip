# grip 🔒

**grip** は、エージェント（Antigravity CLI など）が実行するコマンドに対して高度なパーミッションコントロールを提供する Swift 製の CLI ツールです。

`.agents/hooks.json` 経由でフック呼び出しされ、`.agents/grip.yaml` に定義された設定に従ってコマンド実行の可否（`allow` / `ask` / `deny`）を判定します。

---

## 🌟 主な特徴と評価ロジック

### 1. ルール判定の仕組み
- **Regex Matcher**: `regex` フィールドによるパターンマッチ
- **Exclude Exclusion**: `exclude` フィールドによる特定の例外コマンドの除外
- **Deterministic Decision**: ルールベースの決定 (`allow`, `ask`, `deny`)
- **Agentic Decision**: **Apple Foundation Model** による判定 (`allow_read`, `allow_low_risk`)

### 2. 優先度と決定ルール (Precedence Rules)
1. **複数ルールにマッチする場合**:
   - **より厳しい判定 (deny 優先)** を最優先して採用します。
   - 厳しさの優先順位: `deny` (最優先) > `ask` > `allow`
2. **Deterministic vs Agentic**:
   - 決定ルール (deterministic) と AI 判断ルール (agentic) の両方にマッチする場合、**Deterministic 規則を優先**します。
   - agentic 判断は、deterministic ルールで決定が下されない場合に発動します。

---

## 📄 設定ファイル形式 (`.agents/grip.yaml`)

```yaml
default_decision: ask

rules:
  # 1. Deterministic Deny Rule
  - name: "Block force push to main"
    regex: "^git push (--force|-f) .* (main|master)"
    decision: deny

  # 2. Exclude matching
  - name: "Deny rm -rf except in scratch or tmp"
    regex: "^rm -rf"
    exclude: "^rm -rf (\\./)?(scratch|tmp|\\.build)/"
    decision: deny

  # 3. Deterministic Allow Rule
  - name: "Allow read-only git operations"
    regex: "^git (status|log|diff|show|branch)"
    decision: allow

  # 4. Agentic Decision Rules (Apple Foundation Model)
  - name: "AI Check for read-only status commands"
    regex: "^(cat|ls|pwd|echo|find|grep|rg)"
    agentic: allow_read

  - name: "AI Check for low-risk project scripts"
    regex: "^(npm|yarn|swift|make)"
    agentic: allow_low_risk
```

---

## 🪝 Agent フック統合 (`.agents/hooks.json`)

エージェントツールの実行フックとして以下のように設定します:

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

---

## 🚀 使い方

### ビルド & テスト
```bash
swift build
swift test
```

### CLI による手動コマンド評価
```bash
# 引数渡し
grip "git status"

# JSON 出力指定
grip --json "rm -rf /usr/local"

# Stdin パイプ渡し (.agents/hooks.json 互換)
echo '{"tool": "run_command", "command": "cat README.md"}' | grip --json
```

### Exit Codes
- `0`: **ALLOW** (許可)
- `1`: **ASK** (ユーザー確認要求)
- `2`: **DENY** (拒否)
