#!/usr/bin/env bash
#
# sprint_files.sh — Sprint 의 파일 변경 기록을 git 에서 직접 산출한다.
#
# Sprint 보고서와 docs/SPRINTS.md 의 수치는 반드시 실제 git diff 와 일치해야 한다.
# 손으로 세지 말고 이 스크립트 출력을 그대로 옮긴다.
#
# 사용법:
#   ./scripts/sprint_files.sh <from-ref> [to-ref]
#   ./scripts/sprint_files.sh ab37c17 8b79df7
#   ./scripts/sprint_files.sh ab37c17            # to-ref 생략 시 HEAD
#
# <from-ref> 는 직전 Sprint 의 마지막 커밋이다.
# 저장소 최초부터 세려면 from-ref 자리에 EMPTY 를 쓴다.

set -euo pipefail

FROM="${1:?사용법: $0 <from-ref> [to-ref]}"
TO="${2:-HEAD}"

if [ "$FROM" = "EMPTY" ]; then
    FROM="$(git hash-object -t tree /dev/null)"
fi

STATUS="$(git diff --name-status "$FROM" "$TO")"

count() { printf '%s\n' "$STATUS" | grep -c "^$1" || true; }
list()  { printf '%s\n' "$STATUS" | awk -v k="$1" '$1 ~ "^" k {print "- `" $2 "`"}' | sort; }

echo "범위: $FROM..$TO"
echo
echo "| 구분 | 개수 |"
echo "|---|---:|"
echo "| 생성 | $(count A) |"
echo "| 수정 | $(count M) |"
echo "| 삭제 | $(count D) |"
echo "| 이름 변경 | $(count R) |"
echo
echo "### 생성"
list A
echo
echo "### 수정"
list M

DELETED="$(count D)"
if [ "$DELETED" -gt 0 ]; then
    echo
    echo "### 삭제"
    list D
fi
