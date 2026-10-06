---
name: hook-twin
description: >-
  Make an existing Claude Code hook run on BOTH the Windows CLI and the Linux web
  by creating its cross-platform twin. Use when the user wants a hook to "work on
  the web too" / "work on CLI too" / "양쪽에서 돌게" / "트윈 만들어", or after writing a new
  hook that should run in both environments. Handles only hooks; skills/agents/commands
  are already cross-platform and need no twin.
---

# hook-twin — 훅 양쪽 환경 동기 실행 트윈 생성

이 레포의 훅은 OS별 실행 스크립트라, 한쪽 언어로만 짜면 반대쪽에선 안 돈다. 이 스킬은
기존 훅의 **반대 OS용 트윈**을 정해진 컨벤션대로 만들어 양쪽(Windows CLI + Linux 웹)에서
모두 작동하게 한다. 파일 자체는 레포를 통해 이미 자동 동기화되므로, 핵심은 "반대쪽 OS에서
**실행**되는 버전"을 추가하는 것.

## 언제 발동하나
- "이 훅 웹에서도 돌게 해줘" / "CLI에서도 돌게" / "트윈 만들어" / "양쪽에서 작동"
- 새 훅(.ps1 또는 .sh)을 만든 직후 양쪽에서 돌려야 할 때

스킬·에이전트·슬래시 명령은 OS를 안 가리므로 트윈이 **불필요**하다 — 그런 요청이면 이미
동기화됨을 알리고 끝낸다.

## 절차

### 1. 의미 판단 (가장 먼저)
대상 훅이 **반대쪽 OS에서 실제로 의미가 있는지** 판단한다.
- 로컬 전용(예: `autopull`/`autopush` = 로컬 git 클론 동기화, `cleanup_conversations` =
  `~/.claude/projects` 정리)은 웹에 할 일이 없다 → 트윈을 만들지 말고 그 이유를 설명하고 멈춘다.
- 로직이 portable하고 양쪽에서 의미 있으면 진행.

### 2. 트윈 작성 (반대 언어)
원본과 **동작 패리티**를 맞추되, 반대 OS에서 의미 없는 부분(윈도우 경로 점검, 로컬 동기화
플래그 등)은 의도적으로 뺀다. **첫 실행 줄에 OS 가드**를 넣어, 엉뚱한 OS에서 호출돼도
무해하게 즉시 종료시킨다(원본이 그 OS를 계속 담당).

- **PowerShell → bash** (`.claude/hooks/<name>.sh` — .ps1 원본과 같은 폴더; sync-globals 워크플로가 모든 레포에 자동 배포한다), 첫 줄:
  ```bash
  [ "$(uname -s)" = "Linux" ] || exit 0
  ```
- **bash → PowerShell** (`hooks/<name>.ps1`), 첫 줄:
  ```powershell
  if ($env:OS -ne 'Windows_NT') { exit 0 }
  ```
- 훅 입력 JSON은 stdin으로 들어온다. bash는 `jq`(웹에 있음) 우선, 없으면 grep 폴백.
  UserPromptSubmit 훅의 stdout(exit 0)은 Claude 컨텍스트로 주입된다.

### 3. 등록
- **bash 트윈 (웹용)**: `.claude/settings.json`의 같은 이벤트, 원본 훅 바로 옆에
  파일 가드 패턴으로 추가한다 (파일이 없거나 다른 OS면 조용히 무시됨):
  ```json
  { "type": "command",
    "command": "f=\"${CLAUDE_PROJECT_DIR:-$HOME}/.claude/hooks/<name>.sh\"; [ -f \"$f\" ] || f=\"$HOME/.claude/hooks/<name>.sh\"; [ -f \"$f\" ] && bash \"$f\"",
    "timeout": 10 }
  ```
  다른 레포의 웹 세션까지 도달시키는 배포는 `sync-globals` 워크플로가 자동으로 한다
  (`scripts/sync_globals.sh`가 `.claude/hooks/*.sh`를 전 레포에 vendoring + 훅 등록 병합).
  수동 갱신 명령은 필요 없다 — push만 하면 된다.
- **PowerShell 트윈 (CLI용)**: 기존 컨벤션대로 `~/.claude/hooks/<name>.ps1`에 두고
  `.claude/settings.json`의 같은 이벤트, 원본 훅 바로 옆에 추가한다:
  ```json
  { "type": "command",
    "command": "powershell -NonInteractive -File \"C:\\Users\\brian\\.claude\\hooks\\<name>.ps1\"",
    "shell": "powershell", "timeout": 10 }
  ```

### 4. 검증
- `python3 -c "import json;json.load(open('.claude/settings.json'))"` 로 JSON 유효성.
- bash는 `bash -n <file>`, PowerShell은 가능하면 파서 점검.
- 가능하면 동작 시뮬레이션(예: 가짜 transcript로 스로틀·출력 확인).

### 5. 문서 갱신
`README.md`의 "Running a hook on the web too" 섹션에 새 트윈을 한 줄 추가(어떤 훅을
포팅했는지). 컨벤션 자체는 거기 이미 문서화돼 있으니 중복 설명은 하지 않는다.

### 6. 커밋 & PR
레포 git 컨벤션대로 지정 브랜치에 커밋·push하고, 없으면 draft PR을 만든다.

## 원칙
- **의미 없는 훅은 트윈을 만들지 않는다** (로컬 전용 동기화/정리).
- 트윈은 항상 **OS 가드**로 시작해, 양쪽 settings.json에 있어도 자기 OS에서만 동작.
- 동작 패리티 유지, 단 반대 OS에서 무의미한 로직은 제외.
