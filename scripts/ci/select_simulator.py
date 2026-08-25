#!/usr/bin/env python3
"""
Sprint 0 검증용 iOS Simulator 선택기.

`xcrun simctl list devices available --json` 출력을 stdin 으로 받아,
빌드/테스트에 쓸 Simulator 하나를 고른다.

선택 규칙:
  1. iOS 런타임만 대상으로 한다 (watchOS/tvOS/visionOS 제외).
  2. 배포 타깃(기본 17.0, --min-ios 로 변경) 미만 런타임은 제외한다.
  3. isAvailable 이 true 인 기기만 대상으로 한다.
  4. iPhone 계열만 고른다 (iPad 제외 — TARGETED_DEVICE_FAMILY = 1).
  5. 남은 것 중 런타임 버전이 가장 높은 것, 같으면 이름순 마지막을 고른다.

출력: `<UDID>\t<이름>\tiOS <버전>` 한 줄
종료코드: 0 = 선택됨, 1 = 조건에 맞는 Simulator 없음, 2 = 입력 파싱 실패

이름 대신 UDID 를 쓰는 이유: 같은 이름의 기기가 여러 런타임에 존재할 수 있어
`-destination name=...` 은 모호하다. UDID 는 유일하다.
"""

from __future__ import annotations

import argparse
import json
import re
import sys

RUNTIME_RE = re.compile(r"iOS[-_ ](\d+)[-_.](\d+)")


def parse_runtime_version(runtime_id: str) -> tuple[int, int] | None:
    """'com.apple.CoreSimulator.SimRuntime.iOS-18-2' → (18, 2)"""
    match = RUNTIME_RE.search(runtime_id)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2))


def select(payload: dict, min_ios: tuple[int, int], prefix: str) -> tuple[str, str, tuple[int, int]] | None:
    best: tuple[tuple[tuple[int, int], str], str, str, tuple[int, int]] | None = None

    for runtime_id, devices in payload.get("devices", {}).items():
        version = parse_runtime_version(runtime_id)
        if version is None or version < min_ios:
            continue
        for device in devices:
            if not device.get("isAvailable"):
                continue
            name = device.get("name", "")
            udid = device.get("udid", "")
            if not name.startswith(prefix) or not udid:
                continue
            sort_key = (version, name)
            if best is None or sort_key > best[0]:
                best = (sort_key, udid, name, version)

    if best is None:
        return None
    _, udid, name, version = best
    return udid, name, version


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--min-ios", default="17.0",
                    help="최소 iOS 런타임 버전 (기본 17.0 — docs/DECISIONS.md D-003)")
    ap.add_argument("--prefix", default="iPhone",
                    help="기기 이름 접두사 (기본 iPhone)")
    args = ap.parse_args()

    try:
        major, minor = (int(part) for part in args.min_ios.split(".", 1))
    except ValueError:
        print(f"--min-ios 값이 잘못됐다: {args.min_ios}", file=sys.stderr)
        return 2

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError) as exc:
        print(f"simctl JSON 파싱 실패: {exc}", file=sys.stderr)
        return 2

    result = select(payload, (major, minor), args.prefix)
    if result is None:
        print(
            f"iOS {args.min_ios} 이상 런타임에서 사용 가능한 '{args.prefix}' Simulator 를 찾지 못했다.",
            file=sys.stderr,
        )
        return 1

    udid, name, version = result
    print(f"{udid}\t{name}\tiOS {version[0]}.{version[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
