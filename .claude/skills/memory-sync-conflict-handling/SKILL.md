---
name: memory-sync-conflict-handling
description: >-
  Walks a non-developer user through resolving a Claude Code memory-sync conflict in plain language, while Claude runs all git commands. Trigger when ~/.claude/.memory-sync-conflict exists, when a hook surfaces a one-time sync-conflict notice, or when the user reports memory not syncing / a conflict between devices ("메모리가 안 동기화돼요", "충돌이 났대요", "기억이 꼬였어요"). Only applies on the CLI (Windows or Linux) where memory git-syncs to GitHub — the web app does not participate in this sync.
---

# Memory Sync Conflict Handling

1. **Detect the trigger.** This applies only on the CLI (Windows PowerShell or Linux/web-adjacent CLI environments that sync memory to GitHub) — check for a conflict flag file at `~/.claude/.memory-sync-conflict`, or notice the user describing memory not syncing or a conflict.
   - On the web app: this scenario does not apply — the hosted web app does not participate in CLI↔GitHub memory sync, so there is no conflict flag to check and nothing to resolve there.

2. **Reassure first, in plain language (match the user's language, e.g. Korean for a non-developer user).** Explain that nothing is lost: when the same memory file is edited on both sides and git can't auto-merge, the sync hooks abort the rebase, keep the local copy intact, and just pause — no data was deleted.

3. **Locate and follow the detailed playbook** at `~/.claude/reference/memory-sync-conflict-resolution.md` for the exact resolution steps appropriate to the current OS.

4. **Present the two versions in plain language, not a raw diff.** Summarize what changed in the GitHub version vs. the this-machine version of the affected memory file(s), and offer a recommendation.

5. **Let the user decide — never make them touch git.** Ask them to choose one of: "GitHub 버전" / "이 PC 버전" / "둘 다 합치기" (or the English equivalent if not Korean-speaking). You alone execute every git command needed to apply their choice.

6. **Confirm resolution.** After applying the chosen version, verify both sides (local file and GitHub) now match.

7. **Clear the conflict flag.** The flag clears automatically on the next clean sync; if needed, remove it directly — clear the goal "delete `~/.claude/.memory-sync-conflict` and `~/.claude/.memory-sync-conflict.alerted`":
   - On Windows CLI: `Remove-Item ~/.claude/.memory-sync-conflict, ~/.claude/.memory-sync-conflict.alerted -ErrorAction SilentlyContinue`
   - On Linux CLI: `rm -f ~/.claude/.memory-sync-conflict ~/.claude/.memory-sync-conflict.alerted`

⚠️ Memory sync is a destructive mirror between CLI environments and GitHub: deleting a memory file on one side propagates to the other. Never run bulk/destructive git operations on the user's behalf without walking them through the choice first.
