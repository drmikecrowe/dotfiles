---
name: blog-writer
description: Write blog posts for Mike's 11ty tech blog at ~/Programming/Personal/11ty-blog. Use when asked to write a blog post, draft an article, create a series post, or help structure blog content. Triggers on "write a blog", "blog post", "draft a post", "new article", or any blog writing task.
---

# Blog Writer

Write blog posts for Mike's 11ty blog at `~/Programming/Personal/11ty-blog`.

## Workflow

1. Create post with `scripts/new-post.py "Title"`
2. Write frontmatter and content following the rules below
3. Place featured image in post's `images/` directory

## Frontmatter

```yaml
---
layout: post
title: "Post Title"
description: "SEO one-liner."
date: 2026-04-03T10:00:00.000Z
draft: true
categories:
    - tech
tags:
    - tag1
    - tag2
author: Mike Crowe
seo:
    title: "Post Title"
    description: "SEO description"
    image: images/featured.png
featured_image: images/featured.png
excerpt: "Engaging 1-2 sentence hook for post listings."
---
```

Key: `seo.image` and `featured_image` always match. Images go in `images/` alongside `index.md`.

## AI Disclosure

When AI assisted with the post, add after frontmatter, before content:

```markdown
_This post was written with AI assistance (Claude) for structure and formatting. The analysis, opinions, and [specifics] are entirely my own._
```

## Voice and Tone

- **First person** throughout. Use "I" freely. Share personal context.
- **Conversational and opinionated.** State opinions plainly, don't hedge.
- **Self-deprecating humor.** Acknowledge failure and frustration openly.
- **Parenthetical asides** for side commentary, humor, or context.

## Openers

Pick one pattern:

1. **Confession** (signature pattern):
   ```markdown
   Let me start with a confession:

   > **I expected an expensive cloud model to win.**
   ```

2. **Problem scenario**: "I ran into a case where..."

3. **Rhetorical question**: "Have you ever wished..."

## Post Structure

Follow **Problem -> Journey -> Solution -> Reflection -> Close**:

1. **Hook** — confession, frustration, or interesting question
2. **Context** — why this matters, what you tried
3. **Journey** — show broken/naive approach before the fix
4. **Solution** — the working code/approach
5. **Reflection** — what you learned, caveats, trade-offs
6. **Close** — links to source, invitation to engage

Always show failures before solutions. Readers learn from what broke.

## Code Blocks

- Always language-tag: ````bash`, ````yaml`, ````python`, ````typescript`
- Provide context BEFORE explaining what the code does
- Provide explanation AFTER showing results or key points
- Include actual error output when explaining what went wrong

## Content Patterns

### Section Headers
Use `##` for main sections, `###` for subsections. Descriptive and often conversational.

### Bullet Lists
Use for gotchas, trade-offs, and key takeaways.

### Bold
Use `**bold**` when introducing a key concept or warning.

### Data-Driven Posts
- Lead with the surprise/conclusion, then show the data
- Use markdown tables for comparisons
- Include specific numbers (latency, cost, confidence scores)
- Acknowledge limitations (confidence != accuracy, small sample size)
- Show config/code snippets that produced the results

### Series Posts
Title format: "Topic - Part X of Y". Include navigation block near top:
```markdown
**Part X of Y: [Series Name]**

**Series Overview:**
- **Part 1:** [Title](/posts/...) - Brief description
- **Part 2:** [Title](/posts/...) - Brief description

---
```

## Closing

End with:
1. GitHub link to source code (if applicable)
2. Italic call-to-action:
   ```markdown
   _Have your own [X] stories? Hit me up on [GitHub](https://github.com/drmikecrowe) or wherever you found this post._
   ```

## What to Avoid

- Don't be vague about what failed — show the actual error or broken code
- Don't over-explain obvious concepts if the audience is technical
- Don't skip the "why I tried this approach" narrative — context matters
- Don't end abruptly; close with a reflection or call-to-action
- Don't use corporate-speak ("leverage", "utilize", "synergy")
- Avoid passive voice; say who did what

## Language Patterns

### Transitions
- "Here's the thing:"
- "Here's the secret:"
- "Here's where I ran afoul of..."
- "What a PITA."

### Framing Problems
- "Here's the scenario:"
- "Here are some of the things that drove me crazy:"

### Acknowledging Trade-offs
Always acknowledge what you gave up or what the solution doesn't cover.

## Featured Images

Place in `images/featured.png` (or .jpg). If user provides an image, copy it there. Generate prompts for AI image generators when needed.
