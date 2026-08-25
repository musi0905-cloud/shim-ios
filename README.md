# 쉼 (Shim) — iOS

> 힘든 순간에 사용자의 상태를 이해하고, 음악·시간·화면·움직임 등의 환경을 조합해
> '지금 나에게 필요한 몇 분'을 대신 설계하고 실행해주는 AI 기반 쉼 서비스.
>
> 「쉼」은 **추천 앱이 아니라 실행 앱**이다. 사용자를 앱에 오래 붙잡지 않는다.

**현재 상태: Sprint 2 — Timer Engine ✅ DONE (2026-08-25)**

> 이 저장소는 `musi0905-cloud/App`에서 「쉼」 관련 파일만 분리해 만들었다 (`docs/DECISIONS.md` D-002).
> 무관한 Google Apps Script 프로젝트는 `App` 저장소에 그대로 남아 있다.

[![Sprint 0 Verify (iOS)](https://github.com/musi0905-cloud/shim-ios/actions/workflows/ios-sprint0-verify.yml/badge.svg)](https://github.com/musi0905-cloud/shim-ios/actions/workflows/ios-sprint0-verify.yml)

Sprint 0·1·2 모두 CI 검증을 통과했다 ([Run #6](https://github.com/musi0905-cloud/shim-ios/actions/runs/32796901669) — `BUILD SUCCEEDED` / `TEST SUCCEEDED` 64 tests).
상세 결과는 [`docs/SPRINTS.md`](docs/SPRINTS.md)「CI 검증 결과 기록」참고.
**Sprint 3(Audio PoC)는 Product Owner 승인 후 시작한다.**

---

## 기준 문서

Google Drive 문서가 **최상위 제품 기준**이고, 이 저장소의 문서는 개발 세션에서 빠르게 읽기 위한 **동기화 사본**이다.

| 저장소 문서 | Google Drive 원본 | 내용 |
|---|---|---|
| [`docs/PRODUCT.md`](docs/PRODUCT.md) | 쉼 제품 기획 기준서 v0.1 | 제품 정의, MVP 범위, AI 구조 |
| [`docs/IOS_SPEC.md`](docs/IOS_SPEC.md) | 02_쉼 iOS 개발 명세서 v0.1 | 아키텍처, RestPlan, Service 명세 |
| [`CLAUDE.md`](CLAUDE.md) | 03_쉼 Claude Code 운영규칙 v0.1 | 개발 운영규칙 |
| [`docs/SPRINTS.md`](docs/SPRINTS.md) | 04_쉼 Sprint Backlog v0.1 | Sprint 0~13 계획 및 상태 |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | — | 확정된 기술 결정 기록 (D-001~D-009) |

**문서 간 충돌 시 우선순위**: 제품 기준서 > iOS 개발 명세서 > 운영규칙 > Sprint Backlog

---

## 프로젝트 구조

```
.
├── CLAUDE.md                      # 개발 운영규칙 (Claude Code가 세션마다 읽음)
├── README.md                      # 이 파일
├── .gitignore                     # 시크릿·빌드 산출물 차단
│
├── docs/
│   ├── PRODUCT.md                 # 제품 기획 기준서
│   ├── IOS_SPEC.md                # iOS 개발 명세서
│   ├── SPRINTS.md                 # Sprint Backlog + 현재 상태
│   └── DECISIONS.md               # 기술 결정 기록
│
├── .github/workflows/
│   └── ios-sprint0-verify.yml     # Sprint 0 검증 CI (macOS runner) — AC-1/AC-2/AC-6
│
├── scripts/
│   ├── verify_repo.py             # 저장소 정적 검증 (Linux/Mac 모두 실행 가능)
│   ├── mac_verify.sh              # Mac 로컬 Sprint 0 검증 자동화
│   └── ci/select_simulator.py     # CI용 iOS Simulator 선택기
│
└── ios/
    ├── project.yml                # XcodeGen 스펙 — 프로젝트 정의의 기준 (D-006)
    ├── Shim.xcodeproj/            # 생성된 Xcode 프로젝트 (fallback 용도로 커밋됨)
    │   ├── project.pbxproj
    │   └── xcshareddata/xcschemes/Shim.xcscheme
    │
    ├── Shim/                      # 앱 타깃 소스
    │   ├── ShimApp.swift          # @main 진입점
    │   ├── RootView.swift         # Sprint 0 플레이스홀더 화면
    │   └── Assets.xcassets/       # AppIcon / AccentColor
    │
    └── ShimTests/                 # 유닛 테스트 타깃
        └── ShimSmokeTests.swift   # 스모크 테스트
```

> `ios/` 하위에 둔 이유: Sprint 8에서 `backend/`가 추가된다 (`docs/SPRINTS.md`). 플랫폼별 최상위 분리를 미리 확보한다.

### Sprint 1 이후 추가될 디렉터리

`docs/IOS_SPEC.md` §4의 권장 구조를 따라 `ios/Shim/` 아래에 배치한다.

```
ios/Shim/
├── Features/Home/  Features/RestSession/  Features/RestResult/
├── Models/         # RestPlan, RestSessionState, ...
├── Engine/         # RestPlanExecutor, RestPlanValidator
├── Services/       # Audio/ Timer/ Brightness/ Notification/
├── Persistence/
└── Resources/
```

⚠️ **소스 파일을 추가한 뒤에는 반드시 `cd ios && xcodegen generate`를 다시 실행한다.**
XcodeGen이 생성한 프로젝트는 파일을 명시적으로 나열하므로, 재생성하지 않으면 새 파일이 빌드에 포함되지 않는다.

---

## 요구 환경

| 항목 | 요구사항 |
|---|---|
| OS | **macOS** |
| Xcode | **16.0 이상** |
| XcodeGen | `brew install xcodegen` — **권장 경로** (D-006) |
| 배포 타깃 | **iOS 17.0** (D-003, Product Owner 확정) |
| Swift | 5.0 언어 모드 (D-005) |
| 테스트 | XCTest (D-007) |
| Apple Developer 계정 | Simulator 빌드·테스트에는 **불필요**. 실기기 설치부터 필요 (D-004) |

---

## Sprint 0 검증 (종료 조건)

Product Owner 결정에 따라 **다음 3개가 모두 성공해야 Sprint 0을 DONE 처리한다.**

| # | 검증 | Acceptance Criteria |
|---|---|---|
| 1 | Xcode에서 프로젝트가 열린다 | AC-1 |
| 2 | iOS Simulator 대상 build 성공 | AC-2 |
| 3 | Unit Test 성공 | AC-6 |

개발 세션이 Linux라 로컬 Mac 검증이 불가능하므로 **GitHub Actions macOS runner를 검증 수단으로 사용한다** (D-008).

### 방법 A — GitHub Actions CI (현재 검증 수단)

워크플로: [`.github/workflows/ios-sprint0-verify.yml`](.github/workflows/ios-sprint0-verify.yml)

| 트리거 | 조건 |
|---|---|
| `push` | `main` 브랜치 |
| `pull_request` | 모든 PR |
| `workflow_dispatch` | 수동 실행 (Xcode 버전 지정 가능) |

수행 내용:

1. `macos-latest` runner에서 실행
2. macOS·Xcode·Swift 버전 출력
3. `brew install xcodegen` → `cd ios && xcodegen generate` (D-006 우선 경로)
4. `xcodebuild -list`로 프로젝트 파싱·타깃·스킴 확인 → **AC-1**
5. `xcrun simctl list`로 런타임·기기 확인, iOS 17.0+ iPhone을 UDID로 선택
6. `xcodebuild build` → **AC-2**
7. `xcodebuild test` → **AC-6**
8. 결과를 Job Summary에 표로 기록, 전체 로그를 artifact로 업로드 (성공·실패 모두, 30일)

**결과 확인**: 저장소 → Actions → `Sprint 0 Verify (iOS)` → 해당 run
- **Summary** 탭: 환경 정보와 AC별 통과/실패 표
- **Artifacts**: `sprint0-verify-logs-<번호>` — `xcodebuild` 전체 로그와 `.xcresult` 번들

수동 실행:

```bash
# GitHub 웹: Actions → Sprint 0 Verify (iOS) → Run workflow
# 또는 gh CLI:
gh workflow run "Sprint 0 Verify (iOS)" --ref main
gh run watch
```

### 방법 B — Mac 로컬 (선택)

Mac을 쓸 수 있으면 동일한 3개 항목을 한 줄로 검증할 수 있다.
CI와 병행 가능하며, 실기기 검증(Sprint 3·5)에서도 이 스크립트를 사용한다.

```bash
./scripts/mac_verify.sh
```

- XcodeGen이 있으면 `ios/project.yml` 기준으로 재생성한 뒤 검증한다 (D-006).
- 없으면 커밋된 `ios/Shim.xcodeproj`로 fallback하고 그 사실을 로그에 남긴다.
- 사용 가능한 iPhone Simulator를 자동 탐지한다.
- 로그: `build-logs/mac_verify_<타임스탬프>.log` (gitignore 처리됨)

옵션:

```bash
./scripts/mac_verify.sh --simulator "iPhone 16 Pro"   # Simulator 지정
./scripts/mac_verify.sh --no-xcodegen                 # 커밋된 프로젝트로 검증
./scripts/mac_verify.sh --open                        # 성공 후 Xcode로 열기
```

### 방법 C — 수동 명령 (참고)

위 두 방법이 모두 막혔을 때 아래를 순서대로 실행한다.

```bash
# ── 0. 사전 확인 ────────────────────────────────────────────
xcodebuild -version              # Xcode 16.0 이상인지 확인
xcode-select -p                  # Command Line Tools 경로 확인
brew install xcodegen            # 미설치 시
xcodegen --version

# ── 1. XcodeGen으로 프로젝트 재생성 (우선 경로, D-006) ──────
cd ios
xcodegen generate
# 기대 출력: "Created project at .../ios/Shim.xcodeproj"

# ── 2. Xcode에서 열기  → AC-1 ──────────────────────────────
open Shim.xcodeproj
# 확인: 좌측 네비게이터에 Shim / ShimTests 두 타깃이 보이고,
#       상단 스킴 선택기에 "Shim" 스킴이 있는지

# ── 3. 사용 가능한 Simulator 확인 ──────────────────────────
xcrun simctl list devices available | grep iPhone
# 아래 명령의 name= 값을 여기서 나온 실제 이름으로 바꿔 사용한다

# ── 4. Simulator 대상 빌드  → AC-2 ─────────────────────────
xcodebuild build \
  -project Shim.xcodeproj \
  -scheme Shim \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  | tail -30
# 기대: ** BUILD SUCCEEDED **

# ── 5. Unit Test 실행  → AC-6 ──────────────────────────────
xcodebuild test \
  -project Shim.xcodeproj \
  -scheme Shim \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  | tail -40
# 기대: ** TEST SUCCEEDED **  (ShimSmokeTests 2개 통과)
```

### 검증 실패 시

CI라면 **Actions → 해당 run → Summary**의 실패 로그 발췌와 `sprint0-verify-logs-<번호>` artifact를 확인한다.
로컬이라면 `mac_verify.sh`가 출력하는 실패 단계 번호와 로그 경로를 확인한다.

> `ios/Shim.xcodeproj/project.pbxproj`는 Xcode 없이 수기로 작성됐다.
> **문제가 있으면 억지로 유지하지 않고 `ios/project.yml` 기준으로 재생성한 결과로 교체한다**
> (D-006, Product Owner 결정). CI는 이미 재생성 경로를 사용한다.

### 프로젝트 파일 재생성 후 커밋

`xcodegen generate` 실행 후 `ios/Shim.xcodeproj/project.pbxproj`에 변경이 생기면
**생성된 프로젝트가 기준이므로 그 변경을 커밋한다** (D-006).

---

## 실기기 배포 준비

Sprint 0에는 실기기 검증 항목이 없다. Sprint 3(Audio PoC)부터 필요하다.

1. Xcode에서 `Shim` 타깃 → Signing & Capabilities
2. Team을 본인 Apple ID 팀으로 선택
3. ⚠️ **Team ID가 프로젝트 파일에 기록되므로 커밋 전 `git diff`로 확인한다** (D-004)
   - XcodeGen 경로를 쓴다면 `ios/project.yml`의 `DEVELOPMENT_TEAM`은 빈 값으로 유지하고, 로컬에서만 설정한다

---

## 저장소 정적 검증

Xcode가 없는 환경(Linux 개발 세션 포함)에서도 실행 가능하다.

```bash
python3 scripts/verify_repo.py
```

**검증하는 것**
- Sprint 0 필수 문서·파일 존재 여부
- `project.pbxproj` 구조 정합성 (오브젝트 ID 참조, 괄호 균형, 필수 섹션)
- 동기화 그룹이 가리키는 디렉터리 실존 여부
- 공유 스킴이 실제 타깃을 참조하는지
- `project.yml` ↔ `project.pbxproj` 설정 일치 (배포 타깃 / Swift 버전 / 번들 ID)
- **시크릿 스캔** (API Key, 토큰, 개인키 등 9종 패턴)
- `DEVELOPMENT_TEAM`이 커밋되지 않았는지

**검증하지 않는 것 — 중요**
- Swift 컴파일 여부
- Xcode가 프로젝트를 여는지 (AC-1)
- Simulator 빌드 성공 여부 (AC-2)
- 유닛 테스트 통과 여부 (AC-6)

> **이 스크립트의 PASS는 "빌드 성공"이 아니다.** 위 세 AC는 macOS + Xcode에서만 확인 가능하다.
> 그래서 `scripts/mac_verify.sh`가 따로 있다.

---

## 현재 개발 환경 제약

이 프로젝트의 Claude Code 세션은 **Linux(Ubuntu 24.04)** 에서 실행된다.

| 항목 | 상태 |
|---|---|
| macOS | ❌ 아님 |
| Xcode | ❌ 미설치, 설치 불가 |
| Swift 툴체인 | ❌ 미설치 |
| iOS Simulator | ❌ 사용 불가 |
| 실기기 iPhone | ❌ 연결 불가 |

Xcode와 iOS Simulator는 macOS 전용이며 Linux에서 우회할 방법이 없다.
SwiftUI·UIKit·AVFoundation 등은 Apple 플랫폼 전용이라 Linux Swift 툴체인으로도 컴파일 검증이 불가능하다.

따라서 **AC-1 / AC-2 / AC-6은 이 세션에서 직접 확인할 수 없다.** → `docs/DECISIONS.md` **D-001**

따라서 **GitHub Actions macOS runner가 Sprint 0의 검증 수단이다** (D-008, 2026-08-25 재검토).
`.github/workflows/ios-sprint0-verify.yml` 이 AC-1 / AC-2 / AC-6을 검증한다.

> `CLAUDE.md` §5에 따라, 검증되지 않은 항목을 "완료"라고 보고하지 않는다.

---

## 개발 원칙 요약

전문은 [`CLAUDE.md`](CLAUDE.md)를 참고한다.

- 한 번에 **하나의 Sprint**만 수행한다. 현재 Sprint 완료 전 다음 Sprint를 구현하지 않는다.
- 테스트하지 않은 기능을 "완료"라고 표현하지 않는다.
- 실기기 검증이 필요한 항목은 **"구현 완료 / 실기기 미검증"** 으로 구분해 보고한다.
- **API Key와 secret을 앱이나 Git에 저장하지 않는다.** iOS 앱은 OpenAI API를 직접 호출하지 않는다.
- iOS 비공개 API와 App Store 정책 우회 방식을 사용하지 않는다.
- UI에 iOS 시스템 API 호출 로직을 넣지 않는다. Service 계층이 담당한다.
- 제품 기준서와 충돌하는 기능을 임의로 추가하지 않는다.

---

## 라이선스

미정 — Product Owner 결정 필요.
