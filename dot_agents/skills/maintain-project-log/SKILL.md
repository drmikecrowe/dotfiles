---
name: maintain-project-log
description: Maintains a dated, append-only project log that captures client inputs, direction changes, feedback, and human context alongside GSD's automated artifact trail. Use when the user says "log this", "record that", "add to the log", "note this decision", or when delivering context that should be preserved for handoff — including constraints, preferences, tradeoffs, approvals, feedback, and any input a human provides during a GSD session.
---

<objective>
Capture the human-input layer that GSD's automated artifacts don't record. GSD tracks decisions, requirements, and summaries — but the reasoning, constraints, preferences, and feedback that come from the person running the project often get lost between sessions. This skill maintains a single, dated, append-only log file that fills that gap, creating a complete delivery package when combined with GSD's existing artifact trail.
</objective>

<essential_principles>
## Log Location and Format

The log lives at the project root as `PROJECT-LOG.md`. It uses dated, append-only entries — never reorder, delete, or rewrite past entries. If something changes, add a new entry noting the change.

## What Gets Logged

This log captures things only the human can provide:

- **Constraints** — hard limits, budget boundaries, timeline pressures, regulatory requirements
- **Preferences** — chosen approach over alternatives, style/tone guidance, tool preferences
- **Tradeoffs** — what was weighed, what was chosen, and why
- **Feedback** — review notes, requested changes, approvals with conditions
- **Context** — background about stakeholders, users, business situation, or project history
- **Direction changes** — pivots, scope adjustments, deprioritization decisions
- **Approvals** — explicit sign-offs, conditional approvals, rejected proposals

## What Does NOT Go Here

GSD already captures these — don't duplicate:

- Architectural/pattern decisions → `DECISIONS.md` (use `gsd_decision_save`)
- Requirement status changes → `REQUIREMENTS.md`
- Task/slice completion records → summaries
- Mid-execution steering → `OVERRIDES.md`

If a human decision is structured enough to be a GSD decision, record it with `gsd_decision_save` (with `made_by: 'human'` or `'collaborative'`) and optionally cross-reference from the log.
</essential_principles>

<process>
## Step 1: Determine the Log File Path

Check for an existing `PROJECT-LOG.md` at the project root.

- If it exists → read the last few entries to understand current format and content
- If it doesn't exist → create it using the template below

## Step 2: Classify the Input

Determine what kind of input this is:

| Category | Examples |
|----------|----------|
| constraint | "Must work offline", "Budget capped at X", "Can't use AWS" |
| preference | "Prefer Tailwind over CSS modules", "Use simple naming" |
| tradeoff | "Chose speed over flexibility because deadline", "Simplicity over feature completeness" |
| feedback | "Change the nav layout", "This flow feels wrong", "Looks good, ship it" |
| context | "The client is a school district", "Users are non-technical" |
| direction | "Pivoting to mobile-first", "Deprioritizing the admin panel" |
| approval | "Approved the API design", "Signed off on the wireframes" |
| other | Anything that doesn't fit above but should be preserved |

## Step 3: Append the Entry

Add a new dated entry to `PROJECT-LOG.md`. Each entry has:

1. **Date heading** — `## YYYY-MM-DD`
2. **Summary line** — one sentence capturing the essence
3. **Category tag** — `[constraint]`, `[preference]`, `[tradeoff]`, `[feedback]`, `[context]`, `[direction]`, `[approval]`, or `[other]`
4. **Detail** — the substance of the input, in the human's voice where possible
5. **Source attribution** — who provided this input (if not the current user, note who)

Reuse the date heading if an entry already exists for today. Multiple entries on the same date are normal.

## Step 4: Cross-Reference When Appropriate

If the input also constitutes a formal decision, requirement, or override:

1. Record it through the appropriate GSD mechanism first (`gsd_decision_save`, etc.)
2. Add a cross-reference in the log entry: `See DECISIONS.md DXXX` or `See OVERRIDES.md`

Don't let cross-references replace the human context — the log entry should still capture the "why" in plain language even if the structured artifact exists.

## Step 5: Confirm

Briefly confirm what was logged. Don't repeat the content — just acknowledge the category and that it's captured.
</process>

<template>
## PROJECT-LOG.md Initial Template

```markdown
# Project Log

Dated, append-only record of human inputs, direction, and context. Complements GSD's automated artifacts (DECISIONS.md, REQUIREMENTS.md, summaries).

## YYYY-MM-DD

### [category] Brief summary

Detail in plain language.

**Source:** [who provided this input]

---
```
</template>

<anti_patterns>
<pitfall name="rewriting_history">
Never edit or reorder past entries. The log is append-only. If direction changes, add a new entry — the evolution is part of the record.
</pitfall>

<pitfall name="duplicating_gsd_artifacts">
Don't copy content that belongs in DECISIONS.md or REQUIREMENTS.md. Link to it instead. The log captures the human reasoning layer, not the structured decision layer.
</pitfall>

<pitfall name="agent_voice_injection">
Don't paraphrase the human's input into generic corporate language. Preserve their voice and specificity. "Can't use AWS because of data residency rules in Germany" is better than "Cloud provider constraint noted."
</pitfall>

<pitfall name="logging_every_utterance">
Not every message needs a log entry. Log substantive inputs — things that affect direction, scope, or understanding. Casual questions and quick confirmations don't need entries.
</pitfall>
</anti_patterns>

<success_criteria>
A well-maintained project log:
- Exists at the project root as `PROJECT-LOG.md`
- Contains dated, categorized entries in append-only order
- Preserves human voice and specificity
- Cross-references formal GSD artifacts where appropriate
- Covers the full project timeline from first input to delivery
- Can be handed to a new team member or client as the human-context layer
- Doesn't duplicate content from DECISIONS.md, REQUIREMENTS.md, or summaries
</success_criteria>
