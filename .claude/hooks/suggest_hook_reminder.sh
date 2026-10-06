#!/usr/bin/env bash
# UserPromptSubmit 훅 (웹/Linux 포팅판)
# ---------------------------------------------------------------------------
# suggest_hook_reminder.ps1 의 "반복 패턴 → 자동 훅/스킬 제안" 리마인더만 옮긴
# 크로스플랫폼 버전. 윈도우 전용 부분(메모리 동기화 충돌 알림, C:\ 경로 기반
# 훅 폴더 점검)은 웹에서 의미가 없어 의도적으로 포팅하지 않았다.
#
# 동작 분리(중요): settings.json 은 윈도우 CLI(심링크)와 웹(클론) 양쪽에서
# 로드된다. 윈도우에서는 .ps1 버전이 이 역할을 이미 하므로, 이 스크립트는
# OS 가드로 '리눅스(=웹 컨테이너)일 때만' 동작하고 그 외엔 조용히 종료한다.
# 그래서 윈도우 Git Bash 에서 호출돼도 무해하다.
# ---------------------------------------------------------------------------

# OS 가드: 리눅스(웹)가 아니면 아무것도 하지 않고 종료
[ "$(uname -s)" = "Linux" ] || exit 0

raw="$(cat)"
[ -n "$raw" ] || exit 0

# 훅 입력 JSON 에서 transcript_path 추출 (웹 컨테이너엔 jq 가 있음, 없으면 grep)
if command -v jq >/dev/null 2>&1; then
  transcript="$(printf '%s' "$raw" | jq -r '.transcript_path // empty' 2>/dev/null)"
else
  transcript="$(printf '%s' "$raw" \
    | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*:[[:space:]]*"//; s/"$//')"
fi
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# 사용자 메시지 수 집계 (전체 파싱 대신 type 필드 매칭으로 빠르게)
userMsgs="$(grep -c '"type"[[:space:]]*:[[:space:]]*"user"' "$transcript" 2>/dev/null)"
[ -n "$userMsgs" ] || exit 0

# 스로틀: 패턴이 보일 만큼 쌓였고(>=6) 6턴마다 한 번만 → 매 턴 잔소리 방지
if [ "$userMsgs" -lt 6 ] || [ $((userMsgs % 6)) -ne 0 ]; then
  exit 0
fi

# UserPromptSubmit 훅의 stdout(exit 0)은 Claude 컨텍스트로 주입된다.
cat <<'EOF'
[자동 훅/스킬 제안 리마인더] 지금까지의 대화를 돌아보고, 사용자가 반복적으로 요청한 작업이나 매번 수동으로 처리하는 반복 워크플로(자동화/재사용하면 좋을 패턴)가 있는지 점검하라. 명확하고 실질적인 패턴이 보이면, 아래 기준으로 '자동 훅'과 '스킬' 중 적합한 쪽을 골라 답변 끝에 사용자에게 먼저 제안하라.

- 자동 훅(settings.json hooks)이 적합한 경우: 특정 이벤트가 발생할 때마다 '항상/결정론적으로' 실행되어야 하는 동작. 예) 저장/종료 시 포맷·린트·동기화, 커밋 전 검증. 하니스가 직접 실행하므로 Claude의 판단이 끼어들 필요 없는 자동 동작에 적합. → 어떤 이벤트(Stop/UserPromptSubmit/PostToolUse 등)에서, 무엇을 트리거로, 어떤 스크립트가 동작할지 한두 문장으로 구체적으로 설명.
- 스킬(.claude/skills)이 적합한 경우: 매번 일정한 '절차/도메인 지식'을 따라야 하지만 Claude가 상황을 보고 직접 수행해야 하는 반복 작업. 예) 특정 형식의 보고서 작성, 정해진 단계로 진행하는 배포·리뷰 절차, 프로젝트 고유의 작업 방식. → 스킬 이름, 언제 발동(trigger)할지, 어떤 단계를 수행할지 한두 문장으로 구체적으로 설명.

판단 기준 요약: '조건이 맞으면 사람 개입 없이 매번 자동 실행'이면 훅, 'Claude가 상황 판단 후 정해진 방식대로 직접 수행'이면 스킬. 사용자가 동의하면 그때 실제로 생성하라(스킬은 .claude/skills/<name>/SKILL.md, 훅은 settings.json). 새롭고 실질적인 패턴이 없으면 이 리마인더는 조용히 무시하고 평소대로 답하라(억지로 제안 금지).
EOF
exit 0
