#!/usr/bin/env python3
"""Create a new 11ty blog post with proper folder structure and frontmatter."""

import argparse
import re
from datetime import datetime
from pathlib import Path

BLOG_ROOT = Path("/home/mcrowe/Programming/Personal/11ty-blog/content/posts")


def slugify(title: str) -> str:
    slug = title.lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'[\s_]+', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    return slug.strip('-')


def create_post(title: str, description: str = "") -> str:
    now = datetime.now()
    date_str = now.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    return f"""---
layout: post
title: "{title}"
description: "{description}"
date: {date_str}
draft: true
categories:
    - tech
tags:
    - tech
author: Mike Crowe
seo:
    title: "{title}"
    description: "{description}"
    image: images/featured.png
featured_image: images/featured.png
excerpt: ""
---

Let me start with a confession:

> **[Your confession here]**

## The Problem

[Describe the problem/scenario]

## The Solution

[Explain your approach]

```bash
# your code here
```

Key points:
- Point 1
- Point 2

## The Results

[What you achieved]

"""


def main():
    parser = argparse.ArgumentParser(description="Create a new blog post")
    parser.add_argument("title", help="Post title")
    parser.add_argument("-d", "--description", default="", help="Post description")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    now = datetime.now()
    year = now.strftime("%Y")
    date_prefix = now.strftime("%Y-%m-%d")
    slug = slugify(args.title)
    post_dir = BLOG_ROOT / year / f"{date_prefix}-{slug}"
    index_path = post_dir / "index.md"
    images_dir = post_dir / "images"

    if args.dry_run:
        print(f"Would create:\n  {post_dir}/\n  {index_path}\n  {images_dir}/")
        return

    post_dir.mkdir(parents=True, exist_ok=True)
    images_dir.mkdir(exist_ok=True)
    index_path.write_text(create_post(args.title, args.description))
    print(f"Created:\n  {index_path}\n  {images_dir}/")


if __name__ == "__main__":
    main()
