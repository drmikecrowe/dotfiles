# GSD2 Bedrock Models — Deep Dive

## The `us.` Prefix

The `us.` prefix is an **AWS Bedrock regional variant** — part of the model ID string, not pi/GSD routing magic. It's passed verbatim as the `modelId` parameter to `ConverseStreamCommand`. AWS decides if it's valid.

### Which models have `us.` variants

| Base model | `us.` variant exists? | Notes |
|---|---|---|
| `amazon.nova-*-v1:0` | ✅ | `us.amazon.nova-*-v1:0` |
| `anthropic.claude-*` | ✅ | `us.anthropic.claude-*` |
| `meta.llama*` | ✅ | `us.meta.llama*` |
| `mistral.pixtral-large-*` | ✅ | `us.mistral.pixtral-large-*` |
| `deepseek.r1-v1:0` | ✅ | `us.deepseek.r1-v1:0` |
| **`deepseek.v3.2`** | ❌ | **Missing** — AWS hasn't published this variant |
| **`zai.glm-5`** | ❌ | **Missing** — AWS hasn't published this variant |

Source: `packages/pi-ai/src/models/generated/amazon-bedrock.ts` (auto-generated from models.dev catalog).

### Error if you use a non-existent variant

```
Error: The provided model identifier is invalid.
```

This comes from AWS, not pi. The model ID doesn't exist on the AWS side.

## The deepseek.v3.2 Context Limit

### The problem

`deepseek.v3.2` has `contextWindow: 163840`, `maxTokens: 81920` in the generated catalog. The default behavior requests `maxTokens` output tokens, leaving only `contextWindow - maxTokens` for input. At 81921+ input tokens, the total exceeds 163840:

```
163840 (context) - 81920 (maxTokens) = 81920 (max input)
```

AWS error:
```
This model's maximum context length is 163840 tokens. However, you requested
81920 output tokens and your prompt contains at least 81921 input tokens,
for a total of at least 163841 tokens.
```

### The fix

Override `maxTokens` to 32768 via `models.json`:

```json
{
  "providers": {
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

Result: `163840 - 32768 = 131072` tokens of input headroom.

## Key Bedrock Model Specs

| Model ID | Context | maxTokens (default) | Reasoning | Cost (in/out per 1M) |
|---|---|---|---|---|
| `deepseek.v3.2` | 163840 | 81920 → **32768** (overridden) | true | $0.62 / $1.85 |
| `deepseek.r1-v1:0` | 128000 | 64000 | true | — |
| `us.deepseek.r1-v1:0` | 128000 | 32768 | true | $1.35 / $5.40 |
| `zai.glm-5` | 202752 | 101376 | true | $1.00 / $3.20 |
| `zai.glm-4.7` | — | — | — | — |
| `zai.glm-4.7-flash` | — | — | — | — |

## How Model IDs Flow to the Bedrock API

```
1. User selects model (PREFERENCES.md or /model command)
   ↓
2. tryMatchModel() resolves to a Model object from the registry
   - Model.id = "deepseek.v3.2"  (exact string from generated catalog)
   - Model.provider = "amazon-bedrock"
   - Model.api = "bedrock-converse-stream"
   ↓
3. modelOverrides applied (from models.json)
   - maxTokens: 81920 → 32768
   ↓
4. streamBedrock() constructs the API call:
   - new BedrockRuntimeClient(config) — region from env or us-east-1
   - ConverseStreamCommand({ modelId: model.id })  ← THE EXACT STRING
   ↓
5. AWS receives modelId="deepseek.v3.2" and routes accordingly
```

The provider in `models.json` (`"amazon-bedrock"`) must match the generated model's `provider` field exactly for overrides to apply. The match is: `perModelOverrides.get(m.id)` where `m.id` is the generated model ID.

## The `bareModelId` Function

Used by the model router for cross-provider matching:

```js
function bareModelId(modelId) {
    if (!modelId.includes("/")) return modelId;
    return modelId.split("/").pop() ?? modelId;
}
```

Examples:
- `zai/glm-5` → `glm-5`
- `amazon-bedrock/deepseek.v3.2` → `deepseek.v3.2`
- `deepseek.v3.2` → `deepseek.v3.2` (no slash, returned as-is)

This enables preferences like `zai/glm-5` to match the registry entry `zai.glm-5` via partial matching (step 3 of the resolution pipeline), even though the provider/model split doesn't find an exact match.

## Adding a New Model to models.json

If AWS adds a new Bedrock model that isn't in the generated catalog yet:

```json
{
  "providers": {
    "amazon-bedrock": {
      "models": [
        {
          "id": "us.deepseek.v3.2",
          "name": "DeepSeek-V3.2 (US)",
          "api": "bedrock-converse-stream",
          "contextWindow": 163840,
          "maxTokens": 32768,
          "reasoning": true,
          "input": ["text"],
          "cost": { "input": 0.62, "output": 1.85, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

Note: custom `models[]` entries are additive — they won't overwrite a generated entry with the same ID. If the generated catalog already has the ID, use `modelOverrides` instead.
