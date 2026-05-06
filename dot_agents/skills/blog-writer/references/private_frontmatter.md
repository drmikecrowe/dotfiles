# 11ty Frontmatter Reference

## Standard Post

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
excerpt: "Engaging 1-2 sentence hook."
---
```

## Field Notes

- `title`: Title case, quoted if it has colons/special chars
- `description`: SEO-focused, one sentence
- `date`: ISO 8601 with timezone (`.000Z` for UTC)
- `draft: true` until ready to publish, then `false`
- `categories`: lowercase. Primary: `tech`, `personal`, `pinnacle`
- `tags`: lowercase, hyphenated. Examples: `ai`, `llm`, `linux`, `docker`, `git`
- `excerpt`: Reader-facing preview, can be casual
- `seo.image` and `featured_image`: always match, relative to post directory
- `author`: always `Mike Crowe`

## File Location

Posts: `~/Programming/Personal/11ty-blog/content/posts/YYYY/YYYY-MM-DD-slug/index.md`
Images: `~/Programming/Personal/11ty-blog/content/posts/YYYY/YYYY-MM-DD-slug/images/`
