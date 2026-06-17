---
name: app-store-release-notes
description: Generate concise, nontechnical App Store release notes in English from a user-provided commit range. Use when Codex needs to draft App Store "What's New" copy, App Store change descriptions, release notes for an iOS app submission, or user-facing update text based on git commits.
---

# App Store Release Notes

## Core Rules

- Always write the final App Store copy in English, even when the user asks in another language.
- Require the user to provide the commit range to describe. Do not infer it from the current branch, recent commits, tags, or dates.
- Prefer explicit SHA ranges. Refs such as branches or tags are acceptable only when they can be resolved to concrete SHAs before generation.
- Treat the first endpoint provided by the user as included in the described changes. Do not apply Git's default `A..B` behavior that excludes commit `A` unless the user explicitly asks for native Git range semantics.
- If the range is missing or ambiguous, ask for a clear range instead of drafting release notes.
- Default to one short App Store-ready paragraph. Use bullets only when the user explicitly asks for them.

## Workflow

1. Confirm the requested range.
   - Accept common range forms such as `abc123..def456`, `abc123...def456`, or two explicit endpoints, but interpret them as inclusive endpoint notation for release-note purposes.
   - If refs are used, resolve each ref to its SHA.
   - Show the resolved range with the first included commit as the start SHA, not the internal parent SHA used for Git commands.
2. Inspect the commits and relevant diffs in the range.
   - Include the first endpoint commit when collecting commits and diffs. For a non-root start commit in a linear range, use the start commit's parent as the lower Git bound, for example inspect `start^..end` while reporting `start..end` as the resolved user-facing range.
   - Use commit messages to identify intent.
   - Use diffs to verify what changed and separate user-facing behavior from implementation details.
3. Extract only App Store-relevant changes.
   - Include visible improvements, new user workflows, bug fixes that affect users, polish, performance, reliability, and accessibility when supported by the commits.
   - Omit filenames, commit hashes, internal architecture, dependency updates, tests, refactors, build tooling, and developer-only details unless they directly change the user experience.
4. Draft the note.
   - Write in plain, nontechnical language for end users.
   - Keep the tone concise, clear, and release-ready.
   - Avoid overclaiming. If the range mainly contains internal work, say that the update includes stability and polish improvements without inventing features.

## Output Shape

Return the result as:

```text
Resolved range: <start-sha>..<end-sha>

<one short English App Store paragraph>
```

If the user requested an alternate format, still keep the language nontechnical and App Store-ready.
