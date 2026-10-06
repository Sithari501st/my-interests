---
name: pat-renewal
description: >-
  Finishes a GitHub PAT renewal end to end: confirms each renewed secret actually changed, catches tokens pasted into the wrong secret, really exercises the dependent workflows (bypassing heartbeat skips), then updates pat-registry.json and creates the next D-7/D-1 calendar reminders. Trigger when the user says they want to renew expired/expiring tokens ("토큰 갱신하자", "만료된 토큰", "PAT 갱신했어"), when the check_pat_expiry SessionStart hook surfaces an expiry notice, or when a workflow fails with "401 Bad credentials". CLI only (needs gh, the local registry, and Google Calendar).
---

# PAT Renewal

Source of truth: `~/.claude/reference/pat-registry.json` (array of `{secret, repo, purpose, renewed, expires, warn_days, regenerate_url, secret_update_url, token_name_hint, default_validity_days}`). Background: [[pat-expiry-tracking-system]] memory.

## Hard rules
- **Never ask the user to paste a token into chat.** They paste it straight into the GitHub secret page.
- **Never print a credential value.** Pipe only, and don't even pipe if the auto-mode classifier blocks secret writes. In that case write a no-arg `.ps1` in the scratchpad that does the write and have the user run it with `! powershell -ExecutionPolicy Bypass -File "<path>"`, following the [[feedback-terminal-commands-no-args]] memory. Don't look for a workaround.
- Creating/regenerating the PAT is always the user's manual step in the GitHub UI.
- Any test that changes a repo variable/file must restore the original value afterward.

## 1. Diagnose (before the user does anything)
1. Read the registry; list every entry whose `expires` is past or within `warn_days` of today.
2. For each one, `gh run list -R <repo> -L 10` and pull failure lines from the latest failed run: `gh run view <id> --log-failed | grep -iE "401|bad credentials|denied"`. That shows whether expiry is actually what's broken.
3. **Snapshot every secret's timestamp across all repos** and keep it for step 3:
   `for r in $(gh repo list <owner> -L 100 --json name -q '.[].name'); do gh secret list -R <owner>/$r; done`
4. Tell the user in plain Korean: which token, what's broken, and the exact click path (`regenerate_url` → find `token_name_hint` → Regenerate, `default_validity_days` days → `secret_update_url` → edit **that exact secret row**). Warn them explicitly not to edit a neighboring row.

## 2. Wait for "완료"
Then ask for (or confirm) the validity period, and compute the new expiry as today + days.

## 3. Verify placement
Re-run the full secret snapshot and diff it against step 1.3:
- Expected: each renewed PAT's secret timestamp is now today.
- **Not updated** → that PAT isn't done yet. Tell the user and don't test it.
- **Any other secret changed during the renewal window** → the token was probably pasted in the wrong place. That secret is now broken. Find where its real value can be restored from (e.g. a local credential file named in memory). The secret write may need the user-run script from the hard rules.

## 4. Really exercise each token
Find the workflow that uses the secret: `grep -rn "secrets.<NAME>" <local clone>/.github/workflows/`. Then `gh workflow run` it and `gh run watch`.
- **Watch out for heartbeat-gated workflows**: they skip the real work while the PC is on, so a green run proves nothing. Check that the step using the secret did not come out `skipped`.
  - Gate is a repo **variable** (e.g. claude-config `GMAIL_LAST_LOCAL_RUN`): save the original value, set it 2h in the past, dispatch, wait, then restore the original. If the local task has already written something newer, leave that value alone.
  - Gate is a **committed file** (e.g. gmail-outlook-sync `state/heartbeat.json`): if the cloud already treats the heartbeat as stale, just dispatch. Otherwise don't edit the repo to force it without asking the user; that repo needs disable task → change → re-enable (see the [[gmail-outlook-sync-project]] memory).
- For write-back secrets (e.g. `REPO_SECRETS_PAT` writing `OUTLOOK_CLOUD_TOKEN_CACHE`), also confirm the target secret's timestamp moved.
- A failure that isn't 401/credentials (missing CLI, git state, etc.) is a separate problem. Report it separately, with a risk briefing, before fixing it.

## 5. Close out (each verified PAT)
1. Update that entry's `renewed`/`expires` in the registry, then validate the JSON (`py -I -c "import json;json.load(open(r'<path>',encoding='utf-8'))"`).
2. Create two Google Calendar events at 09:00 Asia/Seoul, popup at 0 min, D-7 and D-1 before the new expiry. Titles:
   - `🔑 <SECRET> 만료 D-7 (<repo name>)`
   - `🔑 <SECRET> 만료 D-1 (<repo name>) — 내일 만료!`
   The description repeats the click path from step 1.4 plus the line `⚠️ 다른 시크릿이 아니라 꼭 <SECRET> 행을 수정할 것`.
   Don't create the events for a PAT that hasn't passed step 4.
3. Final report: a table of token → test result, plus the new expiry date and reminder dates. List anything unresolved separately.
