# Agent Directives — Index

Machine-wide directives for every AI agent, every session. This file is the
entry point for harnesses that do not auto-load a rules folder (GSD/pi and any
other AGENTS.md-reading runtime). Claude Code reads the same rules natively from
`~/.claude/rules/`, which symlinks to the folder below.

## Project-local directives

When working inside a project, additionally read and follow, if present:

- `./CLAUDE.md` or `./AGENTS.md`
- `./.claude/rules/*.md`

Project-local directives augment the global rules above; on conflict, the more
specific (project-local) directive wins.

---

## Tools

Connect and activate the following MCP servers on startup (if they are present).  

**MANDATORY**: You must ask the users one at a time to approve.  Otherwise you will freeze up.

* **codebase-memory-mcp**
* **context-mode**
* **level3-memory**
