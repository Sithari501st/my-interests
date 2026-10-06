#!/usr/bin/env bash
# 메모리 웹 노출(web: true) 제안 자동화 (PostToolUse 훅 — 웹/Linux). suggest_web_memory.ps1 의 트윈.
# ---------------------------------------------------------------------------
# memory/*.md 가 저장됐는데 frontmatter 에 web: true 가 없으면, 웹 노출 가치가 있는지
# Claude 가 재량껏 판단해 사용자에게 "제안"하도록 컨텍스트를 주입한다. 승인 시 Claude 가
# 그때 web: true 를 자동 추가한다(이 훅은 파일을 고치지 않음 — 신호만 준다).
#
# settings.json 은 양쪽에서 로드되므로 OS 가드로 '리눅스(웹)일 때만' 동작한다(윈도우는 .ps1 담당).
# ---------------------------------------------------------------------------

[ "$(uname -s)" = "Linux" ] || exit 0

raw="$(cat)"
[ -n "$raw" ] || exit 0

# 훅 입력 JSON 파싱 (웹엔 jq 있음, 없으면 grep 폴백)
if command -v jq >/dev/null 2>&1; then
  tool="$(printf '%s' "$raw" | jq -r '.tool_name // empty' 2>/dev/null)"
  path="$(printf '%s' "$raw" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
else
  tool="$(printf '%s' "$raw" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
  path="$(printf '%s' "$raw" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
fi

case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac
[ -n "$path" ] || exit 0
# memory/ 안의 .md 만, MEMORY.md 인덱스는 제외
case "$path" in */memory/*.md) ;; *) exit 0 ;; esac
case "$path" in */MEMORY.md) exit 0 ;; esac
[ -f "$path" ] || exit 0

# frontmatter 추출 (첫 줄이 --- 일 때, 그 다음부터 두 번째 --- 전까지). 없으면 대상 아님.
fm="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f{print}' "$path")"
[ -n "$fm" ] || exit 0
# 이미 web: true 면 조용히 종료
printf '%s\n' "$fm" | grep -qE '^[[:space:]]*web:[[:space:]]*true[[:space:]]*$' && exit 0

# dedup: 같은 내용은 한 번만 제안. 웹 컨테이너는 세션 단위라 temp 스탬프면 충분.
base="$(basename "$path" .md)"
if command -v sha1sum >/dev/null 2>&1; then sha="$(sha1sum "$path" | awk '{print $1}')"
else sha="$(shasum "$path" 2>/dev/null | awk '{print $1}')"; fi
[ -n "$sha" ] || sha="nosha"
stampdir="${TMPDIR:-/tmp}/.web-memory-suggested"
mkdir -p "$stampdir"
stamp="$stampdir/$base.$sha"
[ -f "$stamp" ] && exit 0
: > "$stamp"

msg="[웹 메모리 노출 제안 점검] 방금 메모리 파일 '${base}.md' 가 저장됐는데 frontmatter 에 web: true 태그가 없다(지금은 웹/claude.ai/code 세션에 노출되지 않음). 이 메모리의 내용을 보고 웹에 노출할 가치가 있는지 재량껏 판단하라.

- 노출 적합(제안하라): 환경 무관 일반 원칙·코딩 기준, 재사용 절차/워크플로, 프로젝트 공통 규약, 설정 동기화 구조 등 — 웹 세션에서도 유용하고 민감하지 않은 것.
- 노출 부적합(조용히 넘어가라): 머신 로컬 정보(Windows/드라이버/ARM64), 스케줄 작업, 자격증명/비밀, 일회성 프로젝트 상태, 특정 OS 전용 트러블슈팅 등 — 웹에 둘 이유가 없거나 새어 나가면 안 되는 것.

노출이 적합하다고 판단되면, 답변 끝에 사용자에게 '이 메모리(${base}.md)에 web: true 를 달아 웹(claude.ai/code)에도 노출할까요?' 라고 이유 한 줄과 함께 제안만 하라. 사용자가 승인하면 그때 곧바로 ${base}.md 의 frontmatter metadata 블록에 'web: true' 한 줄을 추가하라(추가 확인 없이 자동 태깅). 단, 승인 전에는 절대 먼저 태그를 달지 말 것. 부적합하면 이 점검은 조용히 무시하라(억지 제안 금지)."

# additionalContext JSON 출력 (jq 로 안전 escape, 없으면 최소 수동 escape)
if command -v jq >/dev/null 2>&1; then
  jq -nc --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
else
  esc="$(printf '%s' "$msg" | sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g')"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$esc"
fi
exit 0
