---
version: 1
always_use_skills:
  - caveman
  - verify-before-complete
models:
  research: claude-sonnet-4-6
  planning: claude-opus-4-7
  execution: claude-sonnet-4-6
  execution_simple: claude-haiku-4-5-20251001
  completion: claude-sonnet-4-6
  subagent: claude-sonnet-4-6
budget_enforcement: pause
git:
  auto_push: false
  merge_strategy: squash
  auto_pr: false
  collapse_cadence: milestone
token_profile: balanced
forensics_dedup: true
planning_depth: light
---

# GSD Skill Preferences

See `~/.gsd/agent/extensions/gsd/docs/preferences-reference.md` for full field documentation and examples.
