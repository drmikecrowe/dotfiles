# GSD2 Model Configuration

## Config File Locations

| File | Purpose |
|---|---|
| `~/.gsd-bedrock/agent/models.json` | Custom models, provider overrides, and model overrides (active for this setup) |
| `~/.pi/agent/models.json` | Fallback location (legacy pi path) |
| `~/.gsd/agent/models.json` | Standard GSD path |
| `~/.gsd-bedrock/PREFERENCES*.md` | Named preference profiles with model assignments per phase |

The active path is determined by `getAgentDir()`, which reads `piConfig.configDir` from `package.json`. For this GSD instance: `configDir: ".gsd"` + env override → `~/.gsd-bedrock/agent/`.

## Preference Profiles

Multiple profiles exist as separate files; swap by copying to `PREFERENCES.md`:

| File | Models |
|---|---|
| `PREFERENCES-claude.md` | Claude Opus 4.7 / Sonnet 4.6 / Haiku 4.5 via Anthropic |
| `PREFERENCES-zai.md` | GLM-5 / GLM-4.7-flash via Z.AI |
| `PREFERENCES-privateai.md` | Claude models via PrivateAI mirror |

Each profile's `models:` block assigns models to auto-mode phases:

```yaml
models:
  research: zai/glm-5
  planning: zai/glm-5
  execution: zai/glm-5
  execution_simple: zai/glm-4.7-flash
  completion: zai/glm-5
  subagent: zai/glm-5
```

## models.json Structure

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://nas.drmikecrowe.net:11434/v1",
      "api": "openai-completions",
      "apiKey": "TBD",
      "models": [
        {
          "id": "glm-4.7-flash:latest",
          "name": "GLM 4.7-flash (Local)",
          "contextWindow": 202752,
          "maxTokens": 32000
        }
      ]
    },
    "amazon-bedrock": {
      "modelOverrides": {
        "deepseek.v3.2": {
          "maxTokens": 32768
        }
      }
    }
  }
}
```

### Three features per provider entry

| Field | Effect |
|---|---|
| `models[]` | **Additive only** — adds new models to the registry. Never overwrites generated models with the same ID. |
| `modelOverrides` | **Deep merge** onto existing generated models. Keyed by exact `model.id`. Can override: `maxTokens`, `contextWindow`, `reasoning`, `cost`, `name`, `input`, `headers`, `compat`, `capabilities`. |
| `baseUrl` / `apiKey` / `headers` | Provider-level overrides applied to all models under that provider. |

### Cost override example

```json
"modelOverrides": {
  "deepseek.v3.2": {
    "maxTokens": 32768,
    "cost": {
      "input": 0.62,
      "output": 1.85
    }
  }
}
```

Cost fields are optional — partial override merges with existing values.

## Model Resolution Pipeline

```
PREFERENCES.md → model phase config (e.g. "zai/glm-5")
         ↓
tryMatchModel()
  1. Slash split: provider="zai", modelId="glm-5" → provider match fails
  2. Exact ID match: "glm-5" ≠ "zai.glm-5" → fails
  3. Partial match: "zai.glm-5".includes("glm-5") → ✅ matched
         ↓
Registry returns Model object { id: "zai.glm-5", provider: "amazon-bedrock", ... }
         ↓
Model overrides from models.json applied (deep merge by exact m.id)
         ↓
API handler uses model.id verbatim as Bedrock modelId parameter
```

For bare IDs (no slash):
```
"deepseek.v3.2" → exact match on m.id → ✅ immediate hit
```

### Slash vs bare ID in preferences

| Format | Example | Resolution |
|---|---|---|
| `provider/model` | `zai/glm-5` | Split on `/`, try provider+id match, fall through to partial |
| Bare ID | `deepseek.v3.2` | Direct exact match on `m.id` |
| Bare ID (no match) | `glm-5` | Falls through to partial/fuzzy match on `m.id` and `m.name` |

**Recommendation**: Use bare IDs when they match the registry exactly (`deepseek.v3.2`, `zai.glm-5`). Use `provider/model` format only when the bare ID would be ambiguous across providers.
