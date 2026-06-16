---
name: draft-merge-request
description: Generate an English merge request title and description from the current branch changes since its parent branch. Use when Codex needs to draft MR text, pull request text, merge request summaries, or PR descriptions based on git commits, changed files, and diffs.
---

# Draft Merge Request

## Rules

- Always write the merge request title and description in English.
- Use `scripts/collect_mr_context.sh` to gather branch context before drafting.
- Base the draft on files, commits, and diffs changed since the branch left its parent branch.
- If the current branch is `main`, ask the user how to proceed and which base ref to use before generating MR text.
- If the inferred parent is not `main` or `origin/main`, ask the user whether to continue and which base ref to use before generating MR text.
- If the selected range contains exactly one commit, suggest that commit subject as the MR title.
- For multi-commit ranges, write a title that summarizes the user-facing or project-level intent instead of concatenating commit subjects.
- Do not invent motivation, validation, or consequences that are not supported by the inspected changes.

## Workflow

1. Run the helper from the repository root:

```bash
bash .agents/skills/draft-merge-request/scripts/collect_mr_context.sh
```

2. If the helper refuses because the branch is `main` or because the likely parent is not `main`/`origin/main`, ask the user for the base ref. Then rerun:

```bash
bash .agents/skills/draft-merge-request/scripts/collect_mr_context.sh --base <ref>
```

3. Read the helper output:
   - branch and base refs,
   - merge-base SHA,
   - commit count and subjects,
   - changed files,
   - diff stats and compact diff.
4. Draft the MR title and description from that evidence.

## Output Shape

Return:

```markdown
Title: <merge request title>

Description:
## Summary
<what changed>

## Why
<why the change exists, when supported by commits or diffs>

## Impact
<user, behavior, maintainer, test, release, or compatibility consequences>

## Validation
<tests or checks observed in commits/diffs>
```

Omit `Validation` entirely when there is no meaningful validation evidence to report. Omit any other section only when the inspected changes genuinely do not support it. Keep the description precise and concise; avoid implementation trivia unless it changes impact or risk.
