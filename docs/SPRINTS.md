# docs/SPRINTS.md — 04_쉼 Sprint Backlog v0.1 (동기화 사본)

> **원본**: Google Drive `04_쉼 Sprint Backlog v0.1`
> **동기화일**: 2026-08-24 (Sprint 0)
> **우선순위**: 저장소 문서 중 최하위. 제품 기준서 > iOS 명세서 > 운영규칙 > 이 문서.

---

## 운영 상태

각 Sprint는 `TODO` / `READY` / `IN PROGRESS` / `BLOCKED` / `DONE` 중 하나의 상태를 가진다.
**한 번에 하나의 Sprint만 `IN PROGRESS`가 될 수 있다.**

### 현재 상태 요약 (2026-08-24)

| Sprint | 이름 | 상태 |
|---|---|---|
| 0 | 개발 환경 및 저장소 기초 | ✅ **DONE** (2026-08-25) — CI가 AC 6개 전부 충족 |
| 1 | Foundation & RestPlan | ✅ **DONE** (2026-08-25) — CI 통과 |
| 2 | Timer Engine | ✅ **DONE** (2026-08-25) — CI 통과 |
| 3 | Audio PoC | 🟡 **IMPLEMENTED / DEVICE VERIFICATION BLOCKED** |
| 4 | Brightness & Minimal Screen | TODO |
| 5 | Local Notification | TODO |
| 6 | RestPlanExecutor 통합 | TODO |
| 7 | Feedback & Local Personalization Base | TODO |
| 8 | Backend Skeleton | TODO |
| 9 | OpenAI Rest Director | TODO |
| 10 | Minimal AI UX | TODO |
| 11 | Apple Watch PoC | TODO |
| 12 | Context Awareness PoC | TODO |
| 13 | Screen Time Shield Feasibility | TODO |

> Sprint 0이 `DONE`이 되기 전에는 Sprint 1 코드를 구현하지 않는다. (Product Owner 결정, 2026-08-24)
> Sprint 0 BLOCKED 사유와 해제 조건은 `docs/DECISIONS.md` D-001 / D-002 / D-009 참고.

---

## Sprint 0 — 개발 환경 및 저장소 기초

**상태: DONE** (2026-08-25)

### 목표
Claude Code가 실제 iOS 개발을 수행할 수 있는 환경과 프로젝트 저장소 기준을 확정한다.

### 작업
- [x] macOS 여부 확인 → **Linux (Ubuntu 24.04). macOS 아님**
- [x] Xcode 설치 및 버전 확인 → **미설치, 설치 불가**
- [x] Swift 버전 확인 → **툴체인 미설치**
- [x] Apple Developer 설정 필요 여부 확인 → **필요. 실기기 배포 시 Team ID 필수 (D-004)**
- [x] Git repository 생성 또는 기존 repository 점검 → **기존 `musi0905-cloud/App` 점검 완료 (D-002)**
- [x] 기본 `.gitignore`
- [x] `README.md`
- [x] `CLAUDE.md`
- [x] `docs` 디렉터리 구성
- [x] 제품 기준 문서의 핵심을 repository용 문서로 옮김
- [x] 빈 SwiftUI 앱 생성 → **작성 완료 / CI 빌드 검증 완료**
- [x] Simulator 빌드 확인 → **CI에서 성공 (macos-latest)**

### Acceptance Criteria — 전부 충족 ✅

Product Owner 결정으로 AC-6(Unit Test 성공)이 추가되어 총 6개다 (D-009).

| # | 기준 | 상태 | 근거 |
|---|---|---|---|
| AC-1 | 프로젝트가 Xcode에서 열린다 | ✅ 충족 | CI — `xcodebuild -list` 파싱 성공, 타깃 `Shim`/`ShimTests`·스킴 `Shim` 확인 |
| AC-2 | iOS Simulator 대상 build 성공 | ✅ 충족 | CI — `** BUILD SUCCEEDED **` |
| AC-3 | repository에 비밀정보가 없다 | ✅ 충족 | `scripts/verify_repo.py` 시크릿 스캔 통과 |
| AC-4 | `CLAUDE.md`가 운영규칙을 포함한다 | ✅ 충족 | `verify_repo.py` 운영규칙 8개 항목 확인 |
| AC-5 | 프로젝트 구조·빌드 방법이 README에 기록 | ✅ 충족 | `README.md` |
| AC-6 | **Unit Test 성공** (D-009) | ✅ 충족 | CI — `** TEST SUCCEEDED **`, 2 tests / 0 failures |

### CI 검증 결과 기록 (지시 8)

**워크플로**: `.github/workflows/ios-sprint0-verify.yml`
**Run**: [#1](https://github.com/musi0905-cloud/shim-ios/actions/runs/32792825752) · conclusion `success` · 2026-08-25 00:14–00:18 UTC (약 3분 30초)
**Commit**: `9dabca73e2b9bce2aecc15c772650e40ef77c270`

| 항목 | 값 |
|---|---|
| Runner | `macos-latest` — macOS 26.5.2 (arm64) |
| Xcode | **Xcode 26.6** |
| 프로젝트 생성 | `ios/project.yml` 기준 **XcodeGen 재생성** (D-006 우선 경로) |
| Simulator | **iPhone Air (iOS 26.5)** — UDID 지정 |
| 코드 서명 | `Sign to Run Locally` (ad-hoc) — `DEVELOPMENT_TEAM` 빈 값으로 Simulator 빌드 성공 (D-004 검증됨) |
| Artifact | `sprint0-verify-logs-1` — 49개 파일, 81.5 KB, 30일 보관 |

**빌드 결과**
```
** BUILD SUCCEEDED **
```

**테스트 결과**
```
Test Case '-[ShimTests.ShimSmokeTests testAppEntryPointExists]' passed (0.004 seconds).
Test Case '-[ShimTests.ShimSmokeTests testTestTargetRuns]'      passed (0.001 seconds).
Executed 2 tests, with 0 failures (0 unexpected) in 0.005 seconds
** TEST SUCCEEDED **
```

전체 로그의 실제 `error:` 발생 건수: **0건**.

### 검증으로 확인된 사실

- 수기 작성한 `project.pbxproj`가 아니라 **XcodeGen이 `ios/project.yml`로 재생성한 프로젝트**가 검증을 통과했다. D-006의 우선 경로가 의도대로 동작한다.
- `DEVELOPMENT_TEAM`을 빈 값으로 커밋해도 Simulator 빌드·테스트에 지장이 없다 (D-004).
- 배포 타깃 iOS 17.0(D-003)은 runner의 iOS 26.5 Simulator에서 정상 동작한다.

### 파일 변경 기록

`./scripts/sprint_files.sh EMPTY ab37c17` 산출값이다. 손으로 세지 않는다.

| 구분 | 개수 |
|---|---:|
| 생성 | 20 |
| 수정 | 0 |
| 삭제 | 0 |

저장소를 새로 만들었으므로 전부 생성이다.
초기 이전 18개(D-002) + CI 워크플로 2개(`.github/workflows/ios-sprint0-verify.yml`,
`scripts/ci/select_simulator.py`).

### 완료된 후속 작업

- ✅ **저장소 분리** — `musi0905-cloud/shim-ios`로 이전 완료 (2026-08-25, D-002)
- ✅ **macOS CI 도입** — Sprint 0 검증 수단으로 채택, 첫 실행에서 통과 (2026-08-25, D-008)

---

## Sprint 1 — Foundation & RestPlan

**상태: DONE** (2026-08-25)

### 목표
쉼 실행을 표현하는 Domain 모델과 최소 화면 뼈대를 만든다.

### 작업
- RestPlan 모델 / RestType / AudioMode / MovementType / ScreenMode / RestSessionState
- MockRestPlanFactory
- HomeView / RestSessionView / RestResultView
- 기본 Navigation 흐름
- RestPlan JSON decoding test

### Acceptance Criteria — 전부 충족 ✅

| # | 기준 | 결과 |
|---|---|---|
| 1 | Mock RestPlan 을 생성할 수 있다 | ✅ `MockRestPlanFactory.defaultPlan()` / `shortPlan(minutes:)` |
| 2 | JSON 에서 RestPlan decoding 이 가능하다 | ✅ `docs/PRODUCT.md` §5 예시 JSON 그대로 디코딩 |
| 3 | Home → RestSession → RestResult → Home 흐름이 동작한다 | ✅ `RestFlowCoordinator` — 유닛 테스트 11개로 검증 |
| 4 | 아직 실제 오디오·타이머·밝기 기능은 붙이지 않는다 | ✅ Service 미생성 — `verify_repo.py` 범위 가드로 강제 |
| 5 | 빌드 및 관련 테스트가 성공한다 | ✅ CI — `BUILD SUCCEEDED` / `TEST SUCCEEDED` 37/37 |

### CI 검증 결과 기록

**Run**: [#4](https://github.com/musi0905-cloud/shim-ios/actions/runs/32794940622) · conclusion `success` · 2026-08-25 00:46–00:49 UTC
**Commit**: `bbdf8dec36be5c96dcbeaa202a8facc71d113500`
**환경**: macos-latest / macOS 26.5.2 (arm64) · Xcode 26.6 · iPhone Air (iOS 26.5) · XcodeGen 재생성 (D-006)
**Artifact**: `sprint0-verify-logs-4` — 121개 파일, 134 KB

```
** BUILD SUCCEEDED **
** TEST SUCCEEDED **   37 tests, 0 failures
```

| 테스트 파일 | 개수 | 범위 |
|---|---:|---|
| `RestPlanDecodingTests` | 12 | PRODUCT.md 예시 JSON, 선택 필드 생략, 알 수 없는 enum 2종, 필수 필드 누락, 타입 불일치, 깨진 JSON, 빈 데이터, 왕복, snake_case 키, 파생값 |
| `RestPlanValidatorTests` | 12 | 통과, 경계값, brightness clamp 상·하한, 안내 문장 절삭, 다중 보정, duration 거부 3종, decoding→validation 전체 경로 |
| `RestFlowCoordinatorTests` | 11 | 전체 흐름, 취소 흐름, endCheckin 생략, 중복 start 차단, 재시작, idle no-op, 검증 실패, 복구, 보정 전달, 상태 규칙 |
| `ShimSmokeTests` | 2 | 테스트 타깃 구성 |
| **합계** | **37** | |

### 첫 실행 실패와 원인 (Run #3)

Sprint 1 코드를 처음 push 했을 때 CI 가 Swift 컴파일 전에 실패했다.
원인은 **워크플로의 `xcodebuild -version | head -1`** 이 일으킨 SIGPIPE abort 로,
Sprint 1 코드와 무관했다. 재실행으로 넘기지 않고 원인을 고쳤다 — **D-013**.

### 파일 변경 기록

`./scripts/sprint_files.sh ab37c17 8b79df7` 산출값이다. 손으로 세지 않는다.

| 구분 | 개수 |
|---|---:|
| 생성 | 12 |
| 수정 | 7 |
| 삭제 | 0 |

**생성 (12)**

| 파일 | 역할 |
|---|---|
| `ios/Shim/Models/RestPlan.swift` | API 계약 |
| `ios/Shim/Models/RestPlanEnums.swift` | 계약 어휘 |
| `ios/Shim/Models/RestSessionState.swift` | 세션 상태 |
| `ios/Shim/Models/MockRestPlanFactory.swift` | Mock 계획 |
| `ios/Shim/Engine/RestPlanValidator.swift` | 검증 관문 |
| `ios/Shim/Features/RestFlowCoordinator.swift` | 흐름·상태 단일 소스 |
| `ios/Shim/Features/Home/HomeView.swift` | 홈 |
| `ios/Shim/Features/RestSession/RestSessionView.swift` | 쉼 진행 |
| `ios/Shim/Features/RestResult/RestResultView.swift` | 결과 |
| `ios/ShimTests/RestPlanDecodingTests.swift` | 테스트 12 |
| `ios/ShimTests/RestPlanValidatorTests.swift` | 테스트 12 |
| `ios/ShimTests/RestFlowCoordinatorTests.swift` | 테스트 11 |

**수정 (7)**

| 파일 | 이유 |
|---|---|
| `ios/Shim/RootView.swift` | NavigationStack 연결 |
| `scripts/verify_repo.py` | Sprint 범위 가드 추가 |
| `.github/workflows/ios-sprint0-verify.yml` | D-013 SIGPIPE 수정 |
| `docs/DECISIONS.md` | D-010~D-013 |
| `docs/SPRINTS.md` | Sprint 1 기록 |
| `README.md` | 상태 갱신 |
| `CLAUDE.md` | 상태·계약 기록 |

> **기록 정정 (2026-08-25)**: Sprint 1 완료 보고에서 생성 14 / 수정 5 로 적었으나
> 실제 git diff 는 생성 12 / 수정 7 이다. 나열한 파일 목록 자체는 정확했고 합계만 틀렸다.
> 재발을 막기 위해 `scripts/sprint_files.sh` 를 추가했다. 이후 모든 Sprint 의 파일 수치는
> 이 스크립트 출력을 그대로 옮긴다. 코드 변경은 없다.

### 이 Sprint 의 설계 결정

- **D-010** RestPlan 스키마는 `docs/PRODUCT.md` §5 의 snake_case JSON 계약을 따른다
- **D-011** enum 어휘는 명세에 등장하는 값만 정의 — `RestType` 어휘 확정은 PO 결정 대기
- **D-012** `RestPlanValidator` 를 Sprint 6 에서 Sprint 1 로 앞당김
- **D-013** CI 에서 Apple CLI 출력을 `head` 로 자르지 않는다

### Sprint 2 로 넘기는 항목

- `RestSessionView` 의 "쉼 종료 (임시)" 버튼 — 타이머가 없어 정상 종료 경로를 확인하려고 둔 것이다.
  `TimerService` 가 만료를 알리면 제거한다.
- 남은 시간 표시는 현재 계획된 길이를 그대로 보여준다. 카운트다운이 아니다.

---

## Sprint 2 — Timer Engine

**상태: DONE** (2026-08-25)

### 목표
백그라운드 전환에도 시간 오차가 누적되지 않는 쉼 타이머를 만든다.

### 작업
- TimerService protocol / DefaultTimerService
- startDate/endDate 기반 계산
- remaining time publish
- pause가 필요한지 제품 기준에 맞춰 검토
- 앱 foreground/background 재계산
- 짧은 duration 테스트 주입
- Timer unit tests
- RestSessionView 연동

### Acceptance Criteria — 전부 충족 ✅

| # | 기준 | 결과 |
|---|---|---|
| 1 | 10분 계획을 시작할 수 있다 | ✅ `testTenMinutePlanStartsAtSixHundredSeconds` — 600초 |
| 2 | 백그라운드에 두었다 돌아와도 남은 시간이 실제 경과시간 기준으로 맞다 | ✅ `testForegroundReturnRecalculatesRemaining` / `testReturningFromBackgroundRecalculatesRemaining` |
| 3 | 중복 타이머가 생성되지 않는다 | ✅ `testDuplicateStartIsIgnored` — `scheduler.startCount == 1` |
| 4 | 테스트가 통과한다 | ✅ CI 64/64 |

### Product Owner 추가 요구사항 이행

| # | 요구 | 이행 |
|---|---|---|
| 1 | Pause / Resume 미구현 | ✅ `finish()` 를 `private` 으로 두어 사용자 종료 경로 제거 (D-014) |
| 2 | tick 누적 금지 | ✅ `remaining = max(0, endsAt - now)` · `testTickCountDoesNotAffectRemaining` (D-015) |
| 3 | Clock / Date provider 주입 | ✅ `Clock` + `TickScheduler` 주입 (D-016) |
| 4 | 중복 timer 방지 | ✅ Service 의 `isRunning` 가드 + Coordinator 의 `state.canStart` |
| 5 | background 매초 실행 미보장 | ✅ `Task` 기반 스케줄러는 suspend 시 멈춘다. 복귀 시 `refresh()` 로 재계산 |
| 6 | 프로세스 종료 후 복원 미구현 | ✅ 범위 밖. **B-007** 로 분리 |
| 7 | 임시 종료 버튼 제거 | ✅ 제거. "쉼 그만하기" 만 남기고 `cancelled` 로 처리 |
| 8 | TimerService 는 UI 를 모른다 | ✅ `Foundation` 만 import. `verify_repo.py` 가 `Services/` 의 UI import 차단 |
| 9 | 최소 테스트 9종 | ✅ 아래 표 |
| 10 | 범위 미확대 | ✅ Audio / Brightness / Notification / OpenAI / Location / Watch 미구현 |

### 요구된 최소 테스트 9종

| 요구 항목 | 테스트 |
|---|---|
| 10분 시작 시 600초 | `testTenMinutePlanStartsAtSixHundredSeconds` |
| 시간 경과에 따른 정확한 remaining | `testRemainingReflectsElapsedTime` |
| 종료 시 0 미만으로 내려가지 않음 | `testRemainingNeverGoesBelowZero` |
| 종료 시 completion 1회만 발생 | `testFinishFiresOnlyOnce` |
| background 후 복귀 보정 | `testForegroundReturnRecalculatesRemaining` |
| 종료시간 이후 foreground 복귀 시 즉시 finish | `testForegroundReturnAfterEndFinishesImmediately` |
| 중복 start 방지 | `testDuplicateStartIsIgnored` |
| cancel 이후 completion 발생하지 않음 | `testNoFinishAfterCancel` |
| 재사용 가능한 새 session 시작 | `testCanStartNewSessionAfterFinish` / `AfterCancel` |

### CI 검증 결과 기록

**Run**: [#6](https://github.com/musi0905-cloud/shim-ios/actions/runs/32796901669) · conclusion `success` · 2026-08-25 01:19 UTC
**Commit**: `d90acfc08aa036d92e9c4757ed772273aac01e02`
**환경**: macos-latest / macOS 26.5.2 (arm64) · Xcode 26.6 · iPhone Air (iOS 26.5) · XcodeGen 재생성
**Artifact**: `sprint0-verify-logs-6` — 175개 파일, 174 KB

```
** BUILD SUCCEEDED **
** TEST SUCCEEDED **   Executed 64 tests, with 0 failures (0 unexpected)
```

| 테스트 파일 | 개수 |
|---|---:|
| `RestTimerServiceTests` | 17 |
| `RestPlanDecodingTests` | 12 |
| `RestPlanValidatorTests` | 12 |
| `RestFlowCoordinatorTests` | 11 |
| `RestFlowTimerIntegrationTests` | 10 |
| `ShimSmokeTests` | 2 |
| **합계** | **64** |

전체 타이머 테스트가 1초 안에 끝난다. 주입한 시계 덕분에 10분짜리 쉼의 종료를
검증하는 데 10분이 걸리지 않는다.

### 파일 변경 기록

`./scripts/sprint_files.sh a7f08a6 d90acfc` 산출값이다.
범위는 구현 커밋까지이며, 이 DONE 기록 커밋은 포함하지 않는다.

| 구분 | 개수 |
|---|---:|
| 생성 | 6 |
| 수정 | 7 |
| 삭제 | 0 |

**생성 (6)**

| 파일 | 역할 |
|---|---|
| `ios/Shim/Services/Timer/Clock.swift` | 주입 가능한 시계 |
| `ios/Shim/Services/Timer/TickScheduler.swift` | 화면 갱신 신호 |
| `ios/Shim/Services/Timer/RestTimerService.swift` | `endsAt` 기반 타이머 |
| `ios/ShimTests/TestDoubles.swift` | `MutableClock` / `ManualTickScheduler` |
| `ios/ShimTests/RestTimerServiceTests.swift` | 테스트 17 |
| `ios/ShimTests/RestFlowTimerIntegrationTests.swift` | 테스트 10 |

**수정 (7)**

| 파일 | 이유 |
|---|---|
| `ios/Shim/Features/RestFlowCoordinator.swift` | 타이머 연결, `finish()` private 화, foreground 복귀 |
| `ios/Shim/Features/RestSession/RestSessionView.swift` | 임시 버튼 제거, 남은 시간 표시 |
| `ios/Shim/RootView.swift` | `scenePhase` 관찰 |
| `ios/ShimTests/RestFlowCoordinatorTests.swift` | 자동 종료 경로로 전환 |
| `scripts/verify_repo.py` | 범위 가드 갱신, `Services/` UI import 차단 |
| `docs/DECISIONS.md` | D-014~D-016 |
| `docs/SPRINTS.md` | Sprint 2 기록 |

### 이 Sprint 의 설계 결정

- **D-014** Pause / Resume 을 두지 않는다. `finish()` 는 `private`
- **D-015** `endsAt` 기준 계산. tick 누적 금지. background 는 재계산으로 해결
- **D-016** `Clock` 과 `TickScheduler` 를 주입한다

### Sprint 3 으로 넘기는 것

`RestSessionView` 의 남은 시간은 현재 1초 주기로 갱신된다.
`screenMode` 가 `.dark` 일 때의 화면 처리와 밝기 제어는 Sprint 4 다.

---

## Sprint 3 — Audio PoC

**상태: IMPLEMENTED / DEVICE VERIFICATION BLOCKED** (2026-08-25)

### 목표
쉼 시작 시 로컬 오디오가 자동 재생되고 종료 시 확실히 정리되게 한다.

### 작업
- AudioService protocol / AVFoundation 구현
- 저작권 문제 없는 테스트 오디오 리소스
- play/pause/stop
- AVAudioSession 설정
- Background Audio capability 검토 및 적용
- 오디오 오류 처리
- RestPlan audioMode 연동

### 두 Gate 로 관리한다 (Product Owner 결정, 2026-08-25)

```
Gate A — Implementation / CI          Gate B — Physical Device Verification
  AudioService 구현                     실제 iPhone Background Audio
  RestPlan 연동                         화면 잠금 상태 재생
  CI Build / Test                       interruption / route 검증
        ↓                                       ↓
   CODE COMPLETE  ────────────────────────►   DONE
```

**Gate A 가 통과해도 Gate B 없이는 DONE 이 아니다.**

### Gate A — Implementation / CI ✅ 완료 (2026-08-25)

| # | Acceptance Criteria | 결과 |
|---|---|---|
| 1 | 실제 iPhone 에서 쉼 시작 시 오디오가 재생된다 | ⏳ **Gate B** |
| 2 | 앱이 background 로 가도 의도된 정책대로 동작한다 | ⏳ **Gate B** |
| 3 | 정상 종료·취소 시 오디오가 멈춘다 | ✅ 코드 검증 완료 / 실기기 미검증 |
| 4 | 다른 오디오와 충돌 시 동작이 보고된다 | ⏳ **Gate B** |

**구현 요구사항 12개 이행**

| # | 요구 | 이행 |
|---|---|---|
| 1 | `AudioService` protocol + AVFoundation 구현 | ✅ `AudioService` / `DefaultAudioService` / `AudioPlatform` |
| 2 | View 가 AVFoundation 을 직접 호출하지 않음 | ✅ 계층별 import 가드로 강제 (D-017) |
| 3 | `ValidatedRestPlan.audio` 로 실행 | ✅ `startAudio(mode:)` |
| 4 | 외부 저작권 음원 미사용 | ✅ 자체 생성만 사용 |
| 5 | 테스트 음원 자체 생성 | ✅ `scripts/generate_test_audio.py` (D-018) |
| 6 | 테스트 음원임을 문서에 명시 | ✅ README「테스트 오디오에 대하여」 |
| 7 | `.playback` 우선 | ✅ `.playback` / `.default` / `UIBackgroundModes = audio` |
| 8 | 시작 시 자동 재생, 종료·취소 시 stop/cleanup | ✅ 통합 테스트로 고정 |
| 9 | UI 에 Pause/Resume 없음 | ✅ 프로토콜에 `pause()` 자체가 없다 |
| 10 | OS interruption 내부 pause/resume 허용 | ✅ 전화·Siri·이어폰 분리 5종 테스트 |
| 11 | 오디오 실패가 crash 로 이어지지 않음 | ✅ 실패 경로 7종 테스트 |
| 12 | 실패 시 중단 여부를 자동 결정하지 않음 | ✅ `audioError` 로 드러내기만 함. **D-019 PO 결정 대기** |

**최소 테스트 12종**

| 요구 항목 | 테스트 |
|---|---|
| prepare 성공 | `testPrepareSucceeds` |
| play 성공 | `testPlaySucceeds` |
| stop 성공 | `testStopSucceeds` |
| 중복 play 처리 | `testDuplicatePlayIsIgnored` |
| stop 중복 호출 안전성 | `testRepeatedStopIsSafe` |
| 지원하지 않는 AudioMode | `testUnsupportedModeThrows` |
| 파일 없음 | `testMissingResourceThrows` |
| 재생 초기화 실패 | `testPreparationFailureThrows` |
| RestSession 시작 시 audio 실행 | `testStartingRestStartsAudio` |
| cancel 시 audio stop | `testAudioStopsWhenUserCancels` |
| timer 정상 종료 시 audio stop | `testAudioStopsWhenTimerCompletes` |
| audio 오류 시 crash 없음 | `testAudioPrepareFailureDoesNotStopTheRest` 외 3종 |

### Gate A CI 검증 결과 기록

**Run**: [#8](https://github.com/musi0905-cloud/shim-ios/actions/runs/32798630436) · conclusion `success`
**Commit**: `57b9ad3c95c55fd1fb37df84218470a99cc69215`
**환경**: macos-latest / macOS 26.5.2 (arm64) · Xcode 26.6 · iPhone Air (iOS 26.5) · XcodeGen 재생성
**Artifact**: `sprint0-verify-logs-8` — 253개 파일, 233 KB

```
** BUILD SUCCEEDED **
** TEST SUCCEEDED **   103 tests, 0 failures
```

| 테스트 파일 | 개수 |
|---|---:|
| `AudioServiceTests` (+ `AudioResourceTests`) | 28 |
| `RestTimerServiceTests` | 17 |
| `RestPlanDecodingTests` | 12 |
| `RestPlanValidatorTests` | 12 |
| `RestFlowCoordinatorTests` | 11 |
| `RestFlowAudioIntegrationTests` | 11 |
| `RestFlowTimerIntegrationTests` | 10 |
| `ShimSmokeTests` | 2 |
| **합계** | **103** |

### Gate A 중 발견하고 고친 문제

[Run #7](https://github.com/musi0905-cloud/shim-ios/actions/runs/32798165809) 에서
103개 중 **정확히 1개**가 실패했다 — `testBackgroundAudioCapabilityIsDeclared`.

`INFOPLIST_KEY_UIBackgroundModes` 가 생성된 `Info.plist` 에 조용히 반영되지 않았다.
빌드도 되고 Simulator foreground 재생도 되므로 **실기기 Gate B 에 가서야
"홈 화면으로 나가니 소리가 끊긴다" 로 드러났을 문제**다.
번들 `Info.plist` 를 직접 읽는 테스트를 CI 에 넣어둔 덕분에 코드 단계에서 잡혔다.
실제 `ios/Shim-Info.plist` 로 교체해 해결했다 — **D-020**.

### Gate B — Physical Device Verification ⏳ BLOCKED

**실기기 검증 환경이 아직 없다.** 이 개발 세션은 Linux 이고 iPhone 을 연결할 수 없다 (D-001).
CI 의 macOS runner 도 Simulator 만 제공한다. **Simulator 는 실기기가 아니다.**

검증해야 할 10개 항목과 iPhone 설치 절차는 **`docs/DEVICE_VERIFICATION.md`** 에 정리했다.

핵심 확인 흐름:

```
쉼 시작 → 오디오 자동 시작 → 홈 화면 이동 → 계속 재생
       → 화면 잠금 → 계속 재생 → 쉼 취소/종료 → 즉시 정지 + 세션 정리
```

**Gate B 가 끝나기 전까지 Sprint 3 은 DONE 이 아니다.**

### 파일 변경 기록

`./scripts/sprint_files.sh e5c01ba 57b9ad3` 산출값이다.
범위는 Gate A 구현 커밋까지이며 이 기록 커밋은 포함하지 않는다.

| 구분 | 개수 |
|---|---:|
| 생성 | 8 |
| 수정 | 8 |
| 삭제 | 0 |

### 이 Sprint 의 설계 결정

- **D-017** AudioService 경계. 사용자 Pause 금지 / OS interruption 내부 pause 허용
- **D-018** 테스트 음원은 프로젝트가 직접 생성한다. 제품용 콘텐츠 아님
- **D-019** 오디오 실패 시 쉼 중단 여부 — **PO 결정 대기**
- **D-020** Background Audio 는 실제 Info.plist 로 선언한다

---

## Sprint 4 — Brightness & Minimal Screen

**상태: TODO**

### 목표
쉼 시작 시 시각적 자극을 줄이고 종료 시 시스템 상태를 안전하게 복원한다.

### 작업
- BrightnessService protocol
- 현재 밝기 저장 / targetBrightness 적용 / 범위 clamp
- 종료·취소 시 복원
- 앱 lifecycle에서 복원 전략
- Minimal RestSession UI / 중단 버튼 / 오류 시 fallback

### Acceptance Criteria
- 쉼 시작 시 목표 밝기가 적용된다.
- 정상 종료 시 원래 밝기가 복원된다.
- 중간 취소 시 원래 밝기가 복원된다.
- 지원하지 않는/잘못된 값이 들어와도 앱이 크래시하지 않는다.

---

## Sprint 5 — Local Notification

**상태: TODO**

### 목표
화면을 보지 않고 있어도 쉼 종료 시점을 알려준다.

### 작업
- NotificationService
- 권한 상태 확인 / 권한 요청 UX
- 종료 알림 예약 / 정상 종료 시 예약 정리
- 권한 거부 fallback
- 실기기 알림 테스트

### Acceptance Criteria
- 권한 허용 시 종료 알림을 받을 수 있다.
- 권한 거부 상태에서도 쉼은 정상 작동한다.
- 불필요한 중복 알림이 남지 않는다.

---

## Sprint 6 — RestPlanExecutor 통합

**상태: TODO**

### 목표
하나의 RestPlan이 여러 iOS 기능을 일관된 순서로 실행하고 정리하게 만든다.

### 작업
- RestPlanExecutor / RestPlanValidator
- start / finish / cancel / 오류 처리
- Service 의존성 주입
- 중복 실행 방지
- 통합 테스트

### Acceptance Criteria
- 하나의 Mock RestPlan으로 타이머, 오디오, 밝기, 알림이 함께 시작된다.
- 정상 종료 시 모든 리소스가 정리된다.
- 취소 시 모든 리소스가 정리된다.
- 부분 실패가 앱 크래시나 시스템 상태 방치로 이어지지 않는다.

---

## Sprint 7 — Feedback & Local Personalization Base

**상태: TODO**

### 목표
쉼 후 한 번의 피드백을 저장해 개인화 기반을 만든다.

### 작업
- RestFeedback 모델 (better / same / worse)
- RestHistory 모델 / 로컬 저장 / 최근 쉼 기록
- 피드백 저장 테스트
- 개인정보 최소 저장 검토

### Acceptance Criteria
- 쉼 종료 후 세 가지 중 하나를 선택할 수 있다.
- 선택 결과가 해당 RestPlan과 함께 로컬 저장된다.
- 앱 재실행 후에도 기록이 유지된다.
- 원본 자유입력 전체를 불필요하게 장기 저장하지 않는다.

---

## Sprint 8 — Backend Skeleton

**상태: TODO**

### 목표
OpenAI Key를 앱에 넣지 않는 서버 구조를 만든다.

### 작업
- Backend 프로젝트 결정
- REST API 기본 구조 / `POST /rest-plan`
- 환경변수·secret 관리
- request/response schema
- Mock AI Provider / 에러 응답 규격
- iOS API client / 네트워크 실패 fallback

### Acceptance Criteria
- iOS 앱이 Backend의 Mock RestPlan을 받을 수 있다.
- **API Key나 secret이 iOS 앱 또는 Git에 노출되지 않는다.**
- 네트워크 실패 시 로컬 기본 RestPlan으로 fallback 가능하다.

---

## Sprint 9 — OpenAI Rest Director

**상태: TODO**

### 목표
사용자의 짧은 상태 입력을 구조화된 RestPlan으로 변환한다.

### 작업
- AI Provider interface / OpenAI Provider
- 상태 입력 schema / Structured Output
- RestPlan schema validation
- Safety pre-check / Rest Engine rule validation
- 비정상 출력 fallback
- 요청·응답 로그 최소화

### Acceptance Criteria
- 짧은 입력으로 유효한 RestPlan을 생성할 수 있다.
- 자유 텍스트 대신 schema에 맞는 구조화 출력만 앱으로 전달된다.
- 허용되지 않은 값은 Validator에서 차단된다.
- OpenAI 장애 시 서비스가 완전히 멈추지 않는다.

---

## Sprint 10 — Minimal AI UX

**상태: TODO**

### 목표
사용자가 최소한의 입력으로 AI 기반 쉼을 시작하게 한다.

### 작업
- 현재 상태 Quick Select / 한 줄 입력
- 사용 가능 시간 선택 또는 자동값
- loading 최소화
- AI RestPlan 생성 / "쉼 시작" CTA
- 오류 시 즉시 기본 쉼 제공

### Acceptance Criteria
- 사용자가 앱 실행 후 최소 조작으로 쉼을 시작할 수 있다.
- AI 응답을 기다리며 긴 화면을 보게 하지 않는다.
- AI 실패 시에도 기본 쉼을 시작할 수 있다.
- 앱 체류시간을 늘리는 추가 콘텐츠가 없다.

---

## Sprint 11 — Apple Watch PoC

**상태: TODO**

### 목표
쉼 중 휴대폰을 보지 않아도 되는 경험을 강화한다.

### 작업
- watchOS target / WatchConnectivity
- 남은 시간 동기화 / 짧은 안내 / 햅틱 / 종료 신호
- 연결 실패 fallback

### Acceptance Criteria
- 지원되는 Watch에서 쉼 시작 상태를 확인할 수 있다.
- 핵심 안내를 Watch에서 받을 수 있다.
- Watch가 없어도 iPhone 기능은 동일하게 동작한다.

---

## Sprint 12 — Context Awareness PoC

**상태: TODO**

### 목표
위치, 시간, 날씨 등 환경 맥락을 추천에 제한적으로 활용한다.

### 작업
- Core Location 권한 전략 / 정밀 좌표 최소화
- 시간대 context / 날씨 provider 검토
- 실내·외 또는 이동 가능성 context 설계
- AI payload에 최소 정보 전달

### Acceptance Criteria
- 필요 이상의 위치를 저장하지 않는다.
- 권한 거부 시에도 서비스가 정상 작동한다.
- context가 RestPlan 품질 개선에 사용되지만 필수 의존성이 아니다.

---

## Sprint 13 — Screen Time Shield Feasibility

**상태: TODO**

### 목표
방해 앱 일시 제한 기능의 기술 및 App Store 정책 적합성을 검증한다.

### 작업
- FamilyControls / ManagedSettings / DeviceActivity
- entitlement 필요조건 조사
- 성인 자기관리 use case 적합성 검토
- 테스트 앱 PoC
- App Store 리스크 기록

### Acceptance Criteria
- 가능/불가를 문서로 명확히 결론낸다.
- 정책 리스크가 크면 제품 핵심에서 제외한다.
- 검증 전에는 제품에서 작동한다고 가정하지 않는다.

---

## Sprint 종료 게이트

다음 Sprint로 넘어가기 전 반드시 확인한다.

1. Acceptance Criteria 충족
2. 빌드 결과 기록
3. 테스트 결과 기록
4. 실기기 필요 항목 결과 기록
5. 기술 부채 기록
6. 문서 갱신
7. 사용자에게 Sprint 보고
8. **사용자 승인 또는 명시적 계속 지시**

---

## Backlog 후보 (Sprint 범위 밖에서 발견된 항목)

| ID | 내용 | 발견 Sprint | 상태 |
|---|---|---|---|
| B-001 | 저장소 분리 — 「쉼」 iOS를 `musi0905-cloud/shim-ios`로 분리 | Sprint 0 | ✅ **완료** (2026-08-25, D-002) |
| B-002 | GitHub Actions macOS CI 도입 | Sprint 0 | ✅ **완료** — Sprint 0 검증 수단으로 도입 (2026-08-25, D-008) |
| B-003 | App Icon 실제 에셋 제작 (현재 빈 AppIcon 슬롯) | Sprint 0 | 대기 — 디자인 필요 |
| B-005 | CI actions 버전 상향 (`checkout@v4`/`upload-artifact@v4` → Node 20 deprecation 경고) | Sprint 0 | 대기 — 경고이며 실패 아님 |
| B-006 | Xcode 26.6 / iOS 26 SDK 기준 재검토 — 배포 타깃·Swift 언어 모드(D-003, D-005) | Sprint 0 | 대기 — runner 실제 환경 확인 후 |
| B-007 | 앱 프로세스 종료 후 쉼 세션 복원 (session persistence) | Sprint 2 | 대기 — Sprint 2 범위 밖으로 분리 (D-015) |
| B-008 | CI artifact 크기 — 테스트 실패 시 `.xcresult` 로 55MB 까지 커진다 | Sprint 3 | 대기 — 동작엔 지장 없음 |
| B-004 | 저장소 라이선스 결정 | Sprint 0 | 대기 — Product Owner 결정 필요 |
