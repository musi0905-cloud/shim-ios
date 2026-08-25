# docs/DECISIONS.md — 기술 결정 기록

> 각 Sprint에서 확정된 중요한 기술 결정을 기록한다.
> 상태: `제안` = PO 승인 대기 / `확정` = 승인됨 / `보류` = 조건 충족 시 재검토

---

## D-001. 개발 환경: 현재 세션은 Linux이며 iOS 빌드가 불가능하다

- **Sprint**: 0
- **상태**: 확정 (사실 확인) / 대응 방안은 **PO 결정 필요**
- **문제 구분**: C — 개발 환경 제약

### 확인된 사실 (2026-08-24)

| 확인 항목 | 명령 | 결과 |
|---|---|---|
| OS | `uname -a` | `Linux vm 6.18.44-fc-v21 ... x86_64` |
| 배포판 | `/etc/os-release` | `Ubuntu 24.04.4 LTS (Noble Numbat)` |
| macOS 여부 | `sw_vers` | **명령 없음 → macOS 아님** |
| Xcode | `xcodebuild -version` | **명령 없음 → 미설치** |
| Swift | `swift --version` | **명령 없음 → 툴체인 미설치** |
| Xcode CLI | `xcrun --version` | **명령 없음** |

### 결과

- Xcode, iOS Simulator, `xcodebuild`는 **macOS 전용**이며 Linux에 설치할 수 없다. 우회 수단은 없다.
- SwiftUI / UIKit / AVFoundation / UserNotifications는 Apple 플랫폼 전용 프레임워크이므로
  Linux용 Swift 툴체인을 설치하더라도 **이 프로젝트의 컴파일 검증에는 쓸 수 없다.**
- 따라서 이 환경에서 Sprint 0 Acceptance Criteria 중 **AC-1(Xcode에서 열림)**, **AC-2(Simulator 빌드 성공)** 는
  **검증 불가**이며, 충족했다고 보고해서는 안 된다.

### 이 환경에서 할 수 있는 것 / 없는 것

| 가능 | 불가능 |
|---|---|
| Swift 소스 작성 | Swift 컴파일 |
| `.xcodeproj` 파일 작성 | Xcode로 열어 확인 |
| 프로젝트 구조·참조 정합성 정적 검증 (`scripts/verify_repo.py`) | Simulator 빌드 |
| 문서 작성 및 동기화 | 유닛 테스트 실행 |
| 시크릿 스캔 | 실기기 검증 |

### 대응 옵션 (PO 결정 필요)

**1안 — macOS + Xcode 로컬 환경에서 검증 (권장)**
- PO가 Mac에서 저장소를 clone하고 `ios/Shim.xcodeproj`를 열어 Simulator 빌드를 실행한다.
- 장점: 즉시 확인 가능, 추가 비용 없음, 실기기 검증까지 같은 환경에서 이어진다.
- 단점: 매 Sprint마다 PO의 수동 확인이 필요하다.

**2안 — GitHub Actions macOS 러너로 CI 자동 검증**
- `.github/workflows/ios.yml`에서 `runs-on: macos-latest` + `xcodebuild build test` 실행.
- 장점: Claude Code가 PR/푸시마다 실제 빌드·테스트 결과를 객관적으로 확인할 수 있다. 회귀 방지.
- 단점: GitHub Actions macOS 러너는 분당 과금 배수가 높다. 초기 설정 시간이 필요하다.
- **B-002로 Backlog에 등록됨.**

**3안 — 1안 + 2안 병행**
- CI로 Simulator 빌드/유닛 테스트를 상시 검증하고, 실기기 검증만 PO가 수동 수행.
- 장점: 실기기가 필요한 항목(Sprint 3·5)과 그 외를 깔끔히 분리할 수 있다.
- 단점: 비용과 설정 부담이 가장 크다.

### 채택

| 일자 | 채택안 |
|---|---|
| 2026-08-24 | 1안 — PO의 Mac 로컬 검증 |
| **2026-08-25** | **2안 — GitHub Actions macOS runner** (재검토, D-008) |

로컬 Mac 검증이 불가능한 것으로 확인되어 **2안을 Sprint 0의 검증 수단으로 채택**했다.
`.github/workflows/ios-sprint0-verify.yml` 이 AC-1 / AC-2 / AC-6을 검증한다.

`scripts/mac_verify.sh` 는 폐기하지 않는다. Mac을 쓸 수 있게 되면
동일한 3개 항목을 로컬에서 한 줄로 검증할 수 있고, 실기기 검증(Sprint 3·5)에도 필요하다.

### 결과 (2026-08-25)

**CI가 AC-1 / AC-2 / AC-6을 모두 통과했다.** Sprint 0은 `DONE`이다.
[Run #1](https://github.com/musi0905-cloud/shim-ios/actions/runs/32792825752) — Xcode 26.6 / macOS 26.5.2 / iPhone Air (iOS 26.5).
상세 결과는 `docs/SPRINTS.md`「CI 검증 결과 기록」참고.

이로써 D-001의 제약(이 세션에서 iOS 빌드 불가)은 **여전히 사실이지만 더 이상 blocker가 아니다.**
Sprint 1 이후에도 빌드·테스트 검증은 CI를 통해 수행한다.
단, **실기기 검증(Sprint 3·5)은 CI로 대체할 수 없다.** Simulator는 실기기가 아니다.

---

## D-002. 저장소 분리: 「쉼」 iOS는 `musi0905-cloud/shim-ios`로 분리한다

- **Sprint**: 0
- **상태**: **확정 / 이전 완료** (Product Owner 결정 2026-08-24, 이전 완료 2026-08-25)
- **문제 구분**: D — 제품 결정 필요 → 해결됨

### 배경

작업 대상으로 지정됐던 `musi0905-cloud/App`에는 「쉼」과 **무관한 Google Apps Script 프로젝트**가 있었다.

```
Code.gs (105 KB) / Index.html / Scripts.html / Styles.html / appsscript.json
```

기본 브랜치는 `claude/ai-business-webapp-u1xuwo`이고 커밋 이력도 전부 해당 웹앱 관련이었다.

### 결정 (Product Owner)

1. 「쉼」 iOS 프로젝트는 기존 Apps Script 저장소와 **분리한다.**
2. 새 저장소: **`musi0905-cloud/shim-ios`** (이 저장소)
3. 기존 Apps Script 파일은 **이동하거나 수정하지 않는다.**
4. 「쉼」 관련 파일만 새 저장소로 이전한다.

### 이전 결과

`musi0905-cloud/shim-ios`의 `main` 브랜치에 「쉼」 파일 18개를 초기 커밋으로 옮겼다.

기존 Apps Script 프로젝트 5개 파일(`Code.gs` `Index.html` `Scripts.html` `Styles.html` `appsscript.json`)은
`musi0905-cloud/App`에 **그대로 유지**했다. 이동·수정·삭제하지 않았다.

`App` 저장소의 작업 브랜치 `claude/shim-ios-sprint-0-setup-aalbvo`에서는 이전이 확인된 뒤
「쉼」 파일을 제거했다. 이 브랜치는 `App`의 기본 브랜치에 병합된 적이 없으므로
Apps Script 프로젝트에는 어떤 영향도 없다.

Apps Script 커밋 이력은 가져오지 않았다. 이 저장소는 초기 커밋부터 시작한다.

### 이후 원칙

- **이 저장소가 「쉼」 iOS의 정식 저장소다.** 이후 모든 Sprint 작업은 여기서 수행한다.
- `musi0905-cloud/App`은 Apps Script 프로젝트 전용으로 남는다. 「쉼」 관련 파일을 다시 넣지 않는다.

## D-003. iOS 배포 타깃: iOS 17.0

- **Sprint**: 0
- **상태**: **확정** (Product Owner 결정, 2026-08-24 — "현재대로 iOS 17.0을 유지한다")
- **문제 구분**: B — 플랫폼 제약

### 근거

`docs/IOS_SPEC.md` §3은 "최신 안정 Xcode가 권장하는 현실적인 배포 타깃을 사용하고 **실제 장비 테스트 가능성을 우선**한다"고 규정한다.

- iOS 17.0은 이 프로젝트가 필요로 하는 API(`Observation`, SwiftUI `NavigationStack`, `AVAudioSession`, `UNUserNotificationCenter`, `UIScreen.brightness`)를 모두 포함한다.
- 최신 최소버전으로 올리면 PO가 보유한 실기기가 대상에서 빠질 위험이 있다. iOS 17.0은 그 위험이 낮다.

### 확정

Product Owner가 iOS 17.0 유지를 결정했다. 변경하지 않는다.

향후 변경이 필요해지면 두 곳을 함께 고쳐야 한다 (`scripts/verify_repo.py`가 불일치를 검출한다):
`ios/project.yml`의 `deploymentTarget` / `ios/Shim.xcodeproj/project.pbxproj`의 `IPHONEOS_DEPLOYMENT_TARGET`.

---

## D-004. 코드 서명: Team ID를 저장소에 커밋하지 않는다

- **Sprint**: 0
- **상태**: 확정
- **문제 구분**: B/C

### 결정

- `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = ""` (빈 값)으로 커밋한다.
- 실기기 배포가 필요한 시점(Sprint 3 이후)에 PO가 Xcode의 Signing & Capabilities에서 자신의 Team을 선택한다.
- Xcode가 `project.pbxproj`에 Team ID를 기록할 수 있으므로, 커밋 전 `git diff`로 확인한다.
- `.p12`, `.mobileprovision`, `AuthKey_*.p8` 등 서명 관련 파일은 `.gitignore`에서 차단된다.

### Apple Developer Program 필요 여부

| 목적 | 유료 프로그램 필요 |
|---|---|
| Simulator 빌드·실행 | **불필요** |
| 실기기 설치 (개인 개발자 계정, 7일 만료) | 불필요 |
| Background Audio 등 capability 실기기 검증 | 실기기 설치가 되면 가능 |
| TestFlight 배포, App Store 심사 | **필요 (연 $99)** |

> Sprint 3(Audio PoC)의 실기기 검증부터는 최소한 무료 개인 계정으로 기기 등록이 필요하다.

---

## D-005. Swift 언어 모드: Swift 5 모드로 시작

- **Sprint**: 0
- **상태**: 제안
- **문제 구분**: C

### 결정

`SWIFT_VERSION = 5.0`으로 시작한다.

- Swift 6 언어 모드의 엄격한 동시성 검사는 Sprint 2~6(타이머·오디오·밝기 Service의 액터 경계 설계)에서 대량의 컴파일 오류를 유발할 수 있다.
- 운영규칙 §4 "현재 필요하지 않은 과도한 추상화 도입을 피한다"에 따라, 실행 흐름이 안정화된 뒤 Swift 6 모드 전환을 별도로 검토한다.
- `docs/IOS_SPEC.md` §3의 "Swift Concurrency 우선" 원칙은 언어 모드와 무관하게 유지한다 (`async/await`, `Task`, `actor` 사용).

---

## D-006. 프로젝트 정의의 기준은 `ios/project.yml` (XcodeGen)

- **Sprint**: 0
- **상태**: **확정** (Product Owner 결정, 2026-08-24)
- **문제 구분**: C — 개발 환경 제약

### 배경

이 개발 세션에는 Xcode가 없어 `.xcodeproj`를 Xcode로 생성할 수 없다 (D-001).
Sprint 0에서는 `project.pbxproj`를 수기로 작성했다.

### 결정 (Product Owner)

> "`project.pbxproj` 수기 작성본보다 `ios/project.yml`을 기준으로 XcodeGen 재생성을 우선 검토한다.
> Mac에서 XcodeGen 사용 가능 시 `xcodegen generate` 후 생성 프로젝트를 기준으로 검증한다.
> 기존 수기 pbxproj에 문제가 있으면 억지로 유지하지 않는다."

따라서:

1. **`ios/project.yml`이 프로젝트 정의의 기준(source of truth)이다.**
2. Mac 검증 시 XcodeGen이 있으면 `cd ios && xcodegen generate`로 **재생성한 프로젝트를 기준으로 검증한다.**
   `scripts/mac_verify.sh`가 이 순서를 자동으로 따른다.
3. 커밋된 `ios/Shim.xcodeproj`는 **XcodeGen이 없는 환경을 위한 fallback**이다.
4. 수기 pbxproj에 문제가 발견되면 유지하려 시도하지 않고, **생성된 프로젝트로 교체하고 커밋한다.**

### 두 정의를 모두 커밋하는 이유

`.xcodeproj`를 gitignore하면 XcodeGen 없이는 아무도 프로젝트를 열 수 없다.
따라서 둘 다 커밋하되 **우선순위를 위와 같이 명시**한다.

`scripts/verify_repo.py`가 두 정의의 핵심 설정(배포 타깃 / Swift 버전 / 번들 ID) 일치를 검사한다.

### 재생성 시 주의 — 파일 추가 방식이 달라진다

| | 수기 pbxproj (현재 커밋본) | XcodeGen 생성본 |
|---|---|---|
| 파일 참조 방식 | `PBXFileSystemSynchronizedRootGroup` — 디렉터리 전체 동기화 | 파일을 명시적으로 나열 |
| 소스 추가 시 | 프로젝트 파일 수정 불필요 | **`xcodegen generate` 재실행 필요** |

⚠️ **XcodeGen 경로로 전환한 뒤에는 `ios/Shim/`에 파일을 추가할 때마다 `cd ios && xcodegen generate`를 다시 실행해야 한다.**
Sprint 1부터 파일이 늘어나므로 이 점을 `README.md`에 명시했다.

### 알려진 제약

- 수기 pbxproj는 `objectVersion = 77`이라 **Xcode 16 이상에서만 열린다.**
  Xcode 15 이하라면 XcodeGen 재생성이 사실상 필수다.
- 수기 pbxproj는 **Xcode로 열어 확인하기 전까지 정상 동작을 보장할 수 없다** (D-001).
  `scripts/verify_repo.py`는 구조·참조 정합성만 정적 검사하며 빌드 검증이 아니다.

## D-007. 테스트 프레임워크: XCTest

- **Sprint**: 0
- **상태**: 제안
- **문제 구분**: C

### 결정

유닛 테스트는 **XCTest**로 작성한다.

- Swift Testing(`import Testing`)은 Xcode 16+ 전용이다. XCTest는 모든 Xcode 버전과 CI에서 동작한다.
- D-006의 Xcode 15 이하 fallback 경로에서도 테스트 타깃이 그대로 동작해야 한다.
- Swift Testing 전환은 Xcode 버전이 확정된 뒤 별도로 검토한다.

---

## D-008. GitHub Actions macOS CI를 Sprint 0의 검증 수단으로 도입한다

- **Sprint**: 0
- **상태**: **확정** (Product Owner 재검토 결정, 2026-08-25)
- **문제 구분**: C — 개발 환경 제약

### 결정 이력

| 일자 | 결정 |
|---|---|
| 2026-08-24 | macOS CI를 Sprint 0 필수 조건에서 제외. PO의 Mac 로컬 검증(1안) 채택. Backlog B-002로 유지 |
| **2026-08-25** | **재검토 — Sprint 0의 유일한 blocker가 macOS/Xcode 검증이고 로컬 Mac 검증이 불가능하므로 CI를 검증 수단으로 도입** |

### 재검토 근거 (Product Owner)

> "Sprint 0의 유일한 blocker가 macOS/Xcode 검증이므로 D-008을 재검토한다.
> 현재 개발 환경이 Linux이고 로컬 Mac 검증이 불가능한 경우에만
> GitHub Actions macOS runner를 Sprint 0 검증 수단으로 도입한다.
> **목표는 기능 개발이 아니라 AC-1, AC-2, AC-6 검증이다.**"

D-001에서 확인했듯 이 개발 세션은 Linux이고 Xcode를 설치할 수 없다.
로컬 Mac 검증이 불가능한 상황에서 Sprint 0을 닫을 유일한 수단이 CI다.

### 결정

`.github/workflows/ios-sprint0-verify.yml` 을 도입한다.

| 지시 항목 | 구현 |
|---|---|
| 1. macOS runner 사용 | `runs-on: macos-latest` |
| 2. Xcode 버전 출력 | `xcodebuild -version` + 설치된 Xcode 목록 + macOS/아키텍처 |
| 3. XcodeGen 설치 및 `ios/project.yml`로 프로젝트 생성 | `brew install xcodegen` → `cd ios && xcodegen generate` (D-006 우선 경로) |
| 4. 사용 가능한 iOS Simulator 목록 확인 | `xcrun simctl list runtimes` / `devices available` + `scripts/ci/select_simulator.py` |
| 5. Simulator 대상 build | `xcodebuild build -destination "platform=iOS Simulator,id=<UDID>"` → **AC-2** |
| 6. XCTest 실행 | `xcodebuild test` (동일 destination) → **AC-6** |
| 7. 실패 시 전체 로그 artifact 저장 | `actions/upload-artifact@v4`, `if: always()`, 30일 보관 |
| 8. 성공 시 결과를 Sprint 0 보고서에 기록 | `$GITHUB_STEP_SUMMARY`에 AC 표·환경·테스트 케이스 기록 + `docs/SPRINTS.md` 반영 |

**AC-1(Xcode에서 프로젝트 열기)** 은 `xcodebuild -list -project`로 검증한다.
이 명령은 Xcode의 프로젝트 파서를 그대로 사용하므로, 성공하면 Xcode가 프로젝트를 해석할 수 있다는 뜻이다.
추가로 타깃 `Shim` / `ShimTests` 와 스킴 `Shim` 의 존재를 확인한다.

### 설계상의 선택

- **artifact를 성공 시에도 업로드한다.** 지시 7은 실패 시 저장을 요구하지만,
  지시 8(성공 결과를 보고서에 기록)의 근거를 남기려면 성공 로그도 필요하다.
- **Simulator를 이름이 아닌 UDID로 지정한다.** 같은 이름의 기기가 여러 런타임에 존재할 수 있어
  `-destination name=...` 은 모호하다. 선택 로직은 `scripts/ci/select_simulator.py` 로 분리해
  Linux 개발 세션에서도 fixture로 테스트할 수 있게 했다.
- **iOS 17.0 미만 런타임은 제외한다.** 배포 타깃이 17.0이므로(D-003) 그 미만 런타임에서는 실행되지 않는다.
- **`concurrency`로 중복 실행을 취소한다.** macOS runner는 과금 배수가 높다.
- **`permissions: contents: read`** 로 최소 권한만 부여한다.

### 범위 제한

이 CI의 목적은 **Sprint 0 검증**이다. 기능 개발이나 배포 파이프라인이 아니다.
Sprint 1 이후 CI를 확장할지는 별도로 결정한다.

### 첫 실행 결과 (2026-08-25)

[Run #1](https://github.com/musi0905-cloud/shim-ios/actions/runs/32792825752) — **성공**. 소요 약 3분 30초.

| 항목 | 값 |
|---|---|
| Runner | macOS 26.5.2 (arm64) |
| Xcode | 26.6 |
| Simulator | iPhone Air (iOS 26.5) |
| AC-1 / AC-2 / AC-6 | 모두 통과 |
| Artifact | `sprint0-verify-logs-1` (49 파일, 81.5 KB) |

부수적으로 확인된 사실:
- XcodeGen 재생성 경로가 실제로 동작한다 (D-006 우선 경로 유효).
- `DEVELOPMENT_TEAM` 빈 값으로도 Simulator 빌드·테스트가 된다. 코드 서명은 `Sign to Run Locally` (ad-hoc)로 처리됐다 (D-004 검증).
- runner의 Xcode가 **26.6**, Simulator가 **iOS 26.5**다. 배포 타깃 iOS 17.0(D-003)은 문제없이 동작하나,
  최신 SDK 기준으로 D-003·D-005를 재검토할 여지가 있다 → **B-006**.

### 감수하는 비용

macOS runner는 Linux 대비 과금 배수가 높다. 완화책:
- `concurrency`로 중복 실행 취소
- `timeout-minutes: 40`으로 무한 대기 차단
- **`paths-ignore`로 문서 전용 커밋에서는 실행하지 않음** (첫 실행 후 추가)
- Public 저장소면 GitHub Actions 무료 한도 적용

### 알려진 경고 (실패 아님)

`actions/checkout@v4` 와 `actions/upload-artifact@v4` 가 Node 20 을 타깃해 deprecation 경고가 나온다.
빌드·테스트에는 영향이 없다. 버전 상향은 **B-005**로 Backlog 처리한다.

## D-009. Sprint 0 Acceptance Criteria에 Unit Test 성공(AC-6)을 추가한다

- **Sprint**: 0
- **상태**: **확정** (Product Owner 결정, 2026-08-24)
- **문제 구분**: D — 제품 결정 필요

### 배경

원본 `04_쉼 Sprint Backlog v0.1`의 Sprint 0 Acceptance Criteria는 5개였고 Unit Test 항목이 없었다.

### 결정 (Product Owner)

> "Mac/Xcode 환경에서 다음 검증이 완료된 이후 Sprint 0을 DONE 처리한다.
> Xcode에서 프로젝트 열기 / iOS Simulator 대상 build 성공 / **Unit Test 성공**"

### 결과

Sprint 0의 Acceptance Criteria에 **AC-6 — Unit Test 성공**을 추가한다. 총 6개가 된다.

`ios/ShimTests/ShimSmokeTests.swift`의 스모크 테스트 2개가 통과해야 한다.
이 테스트는 제품 로직을 검증하지 않고, **테스트 타깃이 앱을 host로 로드하고 실행되는지**만 확인한다.
실제 Domain 테스트(RestPlan decoding 등)는 Sprint 1부터 추가한다.

`docs/SPRINTS.md`의 Sprint 0 AC 표에 반영했다.

> Google Drive 원본 문서가 최상위 기준이므로, `04_쉼 Sprint Backlog v0.1`의 Sprint 0 항목에도
> 이 변경을 반영하는 것이 좋다. (운영규칙 §13 — 제품 결정이 바뀌면 구현보다 문서를 먼저 갱신한다)

---

## D-010. RestPlan 스키마는 `docs/PRODUCT.md` §5 의 JSON 계약을 따른다

- **Sprint**: 1
- **상태**: **확정** (Product Owner 지시, 2026-08-25)
- **문제 구분**: D — 제품 결정 필요

### 배경 — 두 문서의 필드 이름이 달랐다

| `docs/PRODUCT.md` §5 (AI 반환 JSON) | `docs/IOS_SPEC.md` §5 (앱 모델) |
|---|---|
| `duration_minutes` | `durationSeconds` |
| `rest_type` | `restType` |
| `audio` | `audioMode` |
| `brightness` | `targetBrightness` |
| `screen_mode` / `watch_guidance` / `end_checkin` | `screenMode` / — / `endCheckin` |
| — | `id`, `guidanceMessages` |

### 결정

**`docs/PRODUCT.md` §5 의 이름과 snake_case JSON 키를 채택한다.**

근거:
1. 운영규칙 §0 의 문서 우선순위 — 제품 기준서 > iOS 개발 명세서.
2. Product Owner 가 제시한 struct 가 PRODUCT.md 쪽과 일치한다.
3. 이 스키마는 **AI Structured Output 의 계약**이다. AI 가 만들 JSON 을 기준으로
   이름을 정하는 편이 변환 계층을 줄인다.

`IOS_SPEC.md` 에만 있던 `id` 와 `guidanceMessages` 는 **기본값이 있는 선택 필드로 추가**했다.
`durationSeconds` 는 저장하지 않고 `durationMinutes` 에서 **파생**시킨다.
두 값을 각각 저장하면 어긋날 수 있고, 계약은 분 단위이며 실행 계층(TimerService)만 초 단위를 쓰기 때문이다.

### 필드별 필수 여부

| 필드 | 필수 | 기본값 |
|---|---|---|
| `duration_minutes` `rest_type` `audio` `movement` `screen_mode` | ✅ 필수 | — |
| `brightness` | 선택 | `nil` (밝기를 바꾸지 않음) |
| `watch_guidance` | 선택 | `false` |
| `end_checkin` | 선택 | `true` |
| `guidance_messages` | 선택 | `[]` |
| `id` | 선택 | 앱이 UUID 생성 |

### 알 수 없는 enum 값은 **거부**한다

`docs/IOS_SPEC.md` §5 는 "안전한 기본값으로 대체하거나 **실행을 거부**한다" 두 가지를 허용한다.
둘 중 **거부**를 택했다.

- 조용히 기본값으로 바꾸면 AI 가 계약에 없는 값을 보내도 아무도 모른다.
  잘못된 프롬프트나 스키마 드리프트가 그대로 굳는다.
- 거부하면 Backend 로그와 앱 오류로 즉시 드러난다.
- 사용자 영향은 Sprint 10 의 fallback 이 흡수한다 — "AI 실패 시에도 기본 쉼을 시작할 수 있다."

반면 **숫자 범위는 보정(clamp)** 한다. 값의 의미는 맞고 범위만 벗어난 경우이며,
밝기 문제로 쉼 전체가 실패해서는 안 되기 때문이다 (`IOS_SPEC.md` §7.3).

### 실행 파이프라인

```
AI JSON
  ↓  RestPlan decoding      Models/RestPlan.swift        — 계약 위반이면 throw
  ↓  RestPlan validation    Engine/RestPlanValidator.swift — 거부 또는 보정
  ↓  RestEngine             (이후 Sprint)
  ↓  Execution Layer        (Sprint 2~6)
```

검증을 통과한 계획만 `ValidatedRestPlan` 타입이 된다.
실행 계층은 `RestPlan` 이 아니라 `ValidatedRestPlan` 만 받는다.
**검증되지 않은 계획이 실행되는 경로를 타입 수준에서 막기 위해서다.**

### 스키마 변경 시 함께 갱신할 것

`Models/RestPlan.swift` · `Models/RestPlanEnums.swift` · Backend JSON Schema ·
`docs/PRODUCT.md` §5 · `docs/IOS_SPEC.md` §5

---

## D-011. RestPlan enum 어휘는 명세에 등장하는 값만 정의한다

- **Sprint**: 1
- **상태**: **제안 — 어휘 확정은 Product Owner 결정 필요**
- **문제 구분**: D

### 결정

Product Owner 지시 — "enum 값은 향후 확장을 고려하되 현재 명세에 없는 값을 임의로 많이 만들지 않는다."

각 case 는 출처를 주석으로 남겼다.

| enum | case | 출처 |
|---|---|---|
| `RestType` | `environment_reset` | PRODUCT.md §5, IOS_SPEC.md §5 예시 |
| `AudioMode` | `calm_acoustic` | PRODUCT.md §5 예시 |
| | `nature_sound` | PRODUCT.md §6 Rest Blocks `NATURE_SOUND` |
| | `silence` | PRODUCT.md §6 Rest Blocks `SILENCE` |
| `MovementType` | `slow_walk` | PRODUCT.md §5, IOS_SPEC.md §5 예시 |
| | `stretch` | PRODUCT.md §6 Rest Blocks `STRETCH` |
| | `none` | PRODUCT.md §6 규칙 (이동 불가 상황) |
| `ScreenMode` | `minimal` | IOS_SPEC.md §8.2 |
| | `dark` | PRODUCT.md §6 Rest Blocks `DARK_SCREEN` |

### Product Owner 결정 필요 — `RestType` 어휘

**`RestType` 에 명세가 제시하는 값은 `environment_reset` 하나뿐이다.**
지시 3에 따라 임의로 늘리지 않았으나, case 가 하나면 AI 가 쉼의 유형을 구분할 수 없다.

`docs/PRODUCT.md` §6 의 Rest Blocks 10종(`WALK` `MUSIC` `NATURE_SOUND` `BREATHING`
`STRETCH` `SILENCE` `DARK_SCREEN` `WATCH_GUIDE` `NO_PHONE` `SHORT_REFLECTION`)은
*쉼의 구성 요소*이지 *쉼의 유형*이 아니라서 그대로 `RestType` 에 넣기 어렵다.

Sprint 9(OpenAI Rest Director) 전까지 다음 중 하나를 결정해야 한다.

- **1안** — `RestType` 어휘를 PO 가 확정한다 (예: `environment_reset` / `cognitive_reset` / `social_reset`).
  AI 가 상태 유형을 분류하는 축이 생긴다. 제품 기준서 갱신이 필요하다.
- **2안** — `RestType` 을 없애고 Rest Blocks 조합으로만 표현한다.
  PRODUCT.md §6 의 Rest Engine 설계와 더 가깝지만 계약이 커진다.
- **3안** — 현행 유지. Sprint 9 에서 실제 AI 출력을 보고 결정한다.

> Claude Code 는 승인 없이 제품 어휘를 늘리지 않는다 (운영규칙 §12).

---

## D-012. Sprint 1 에 RestPlanValidator 를 앞당겨 구현한다

- **Sprint**: 1
- **상태**: **확정** (Product Owner 지시, 2026-08-25)
- **문제 구분**: D

### 배경

`docs/SPRINTS.md` 상 `RestPlanValidator` 는 Sprint 6(RestPlanExecutor 통합) 항목이었다.

### 결정

Product Owner 지시로 Sprint 1 에 앞당긴다.

> "brightness 처럼 기기 기능과 직접 연결되는 값도 AI 가 아무 숫자나 주는 구조가 아니라
> 앱이 validation 하는 구조로 가야 해. 이 흐름을 Sprint 1부터 깔아두면 이후 Sprint 가 훨씬 편해져."

### 근거

- Validator 는 시스템 프레임워크에 의존하지 않는 **순수 규칙**이다. Service 없이 구현·테스트할 수 있다.
- 실행 계층이 `ValidatedRestPlan` 만 받도록 타입을 먼저 고정해두면,
  Sprint 2~6 에서 Service 를 붙일 때 검증 우회 경로가 생기지 않는다.
- 나중에 끼워 넣으면 이미 작성된 호출부를 전부 고쳐야 한다.

### Sprint 6 에 남는 것

`RestPlanExecutor` 본체, Service 의존성 주입, 시작·종료·취소 오케스트레이션, 통합 테스트.
Validator 는 Sprint 6 에서 Executor 가 호출하기만 하면 된다.

---

## D-013. CI 에서 `xcodebuild -version | head -1` 을 쓰지 않는다

- **Sprint**: 1
- **상태**: 확정 (2026-08-25)
- **문제 구분**: C — 개발 환경 제약

### 증상

Sprint 1 첫 CI 실행([Run #3](https://github.com/musi0905-cloud/shim-ios/actions/runs/32794527216))이
Swift 코드를 컴파일하기도 전에 4번 스텝에서 실패했다.

```
*** Terminating app due to uncaught exception 'NSFileHandleOperationException',
    reason: '*** -[_NSStdIOFileHandle writeData:]: Broken pipe'
    4  xcodebuild  -[XcodebuildPreIDEHandler handleVersionWithArguments:] + 616
##[error]Process completed with exit code 134.
```

### 원인

`xcodebuild -version` 은 두 줄을 출력한다.

```
Xcode 26.6
Build version 17F113
```

`xcodebuild -version | head -1` 에서 `head` 는 첫 줄을 읽고 즉시 종료하며 파이프를 닫는다.
`xcodebuild` 는 SIGPIPE 를 처리하지 않고 `NSFileHandle writeData:` 로 둘째 줄을 쓰다가
**uncaught Objective-C 예외로 abort** 한다 (exit 134).
`set -euo pipefail` 이 걸려 있어 스텝 전체가 실패한다.

**타이밍 의존이다.** `xcodebuild` 가 두 줄을 모두 써넣고 종료한 뒤에 `head` 가 파이프를 닫으면
아무 일도 일어나지 않는다. Run #1·#2 가 통과한 이유이고, Run #3 에서 처음 드러난 이유다.

### 조치

파이프로 자르지 않는다. 출력을 파일로 받은 뒤 `sed` 로 읽는다.

```bash
xcodebuild -version > "$LOG_DIR/xcodebuild-version.txt" 2>&1
XCODE_FULL="$(sed -n '1p'  "$LOG_DIR/xcodebuild-version.txt")"
XCODE_MAJOR="$(sed -n 's/^Xcode \([0-9]*\).*/\1/p' "$LOG_DIR/xcodebuild-version.txt")"
```

부수 효과로 버전 원본이 artifact 에 남아 진단이 쉬워진다.

### 규칙

**CI 에서 Apple 커맨드라인 도구의 출력을 `head` 로 자르지 않는다.**
`xcodebuild` `xcrun` `simctl` 등은 SIGPIPE 를 처리하지 않을 수 있다.
`tail` 은 입력을 끝까지 읽으므로 안전하다. 잘라야 하면 파일로 받은 뒤 `sed`/`awk` 를 쓴다.

### 배운 것

간헐적으로만 재현되는 실패라도 "flake" 로 넘기고 재실행하지 않는다.
로그에 원인이 정확히 남아 있었고, 재실행했다면 통과했겠지만 다음 Sprint 에서 다시 터졌을 것이다.

---

## D-014. 쉼 타이머에 Pause / Resume 을 두지 않는다

- **Sprint**: 2
- **상태**: **확정** (Product Owner 지시, 2026-08-25)
- **문제 구분**: D — 제품 결정 필요

### 결정

> "「쉼」의 철학은 사용자가 타이머를 관리하는 게 아니라 **'10분 동안 맡긴다'** 에 가까워.
> Pause / Resume 을 넣으면 다시 사용자가 시간을 관리해야 해."

허용되는 흐름은 두 가지뿐이다.

```
Start → Running → Automatic Finish
Start → Running → User Cancel
```

### 코드에 고정한 방법

`RestFlowCoordinator.finish()` 를 **`private`** 으로 뒀다.
`RestTimerService` 가 시간 만료 시에만 호출한다.
사용자가 "다 쉬었다"고 눌러 끝내는 경로를 타입 수준에서 없앤다.

사용자에게 주는 출구는 `cancel()` 하나이고, 화면에는 **"쉼 그만하기"** 버튼 하나만 있다.
이것은 정상 완료와 명확히 다른 `cancelled` 상태·`FinishReason.cancelled` 로 처리된다.

`docs/IOS_SPEC.md` §7.1 의 "pause 가 필요한지 제품 기준에 맞춰 검토" 는 이 결정으로 닫힌다.

---

## D-015. 남은 시간은 `endsAt` 기준으로 계산한다. tick 을 누적하지 않는다

- **Sprint**: 2
- **상태**: 확정
- **문제 구분**: B — 플랫폼 제약

### 계산 규칙

```
startedAt + duration = endsAt
remaining = max(0, endsAt - now)
```

`endsAt` 하나가 남은 시간의 source of truth 다.

**tick 은 화면을 다시 그리라는 신호일 뿐이다.** tick 횟수를 세지 않는다.
`RestTimerServiceTests.testTickCountDoesNotAffectRemaining` 이 이를 고정한다 —
시계를 그대로 두고 tick 을 100번 발생시켜도 남은 시간은 변하지 않아야 한다.
tick 누적 방식이었다면 이 테스트가 깨진다.

### background 에 대한 입장

**background 에서 매초 코드를 돌리려 하지 않는다.** iOS 가 앱을 suspend 할 수 있고,
그것을 보장할 수도 없으며 그럴 필요도 없다.

```
10:00  시작, endsAt = 10:10
10:03  background → iOS 가 suspend. tick 안 돎.
10:08  foreground 복귀 → refresh()
       remaining = 10:10 - 10:08 = 2분

10:14 에 돌아왔다면
       remaining = max(0, 10:10 - 10:14) = 0 → 즉시 종료 → RestResult
```

`DisplayTickScheduler` 는 `Task` 기반이라 앱이 suspend 되면 자연히 멈춘다. 의도된 동작이다.
복귀 시 `RestFlowCoordinator.handleReturnToForeground()` 가 `refresh()` 를 불러 다시 계산한다.

이 구조라야 "휴대폰을 내려놓고 있어도 쉼은 계속된다" 는 경험이 성립한다.

### 이번 Sprint 의 범위 밖

**앱 프로세스가 종료된 뒤의 복원은 구현하지 않는다.**
`endsAt` 은 메모리에만 있다. 프로세스가 죽으면 세션도 사라진다.
현재 범위는 **프로세스가 유지된 상태에서의 foreground/background 전환 정확성**이다.
프로세스 종료를 넘는 session persistence 는 별도 요구사항으로 분리한다 — **B-007**.

---

## D-016. Clock 과 TickScheduler 를 주입한다

- **Sprint**: 2
- **상태**: 확정
- **문제 구분**: C

### 결정

`DefaultRestTimerService(clock:scheduler:)` 로 둘 다 주입한다.

| 프로토콜 | 운영 구현 | 테스트 구현 |
|---|---|---|
| `Clock` | `SystemClock` (`Date()`) | `MutableClock` — `advance(by:)` 로 시간을 앞당긴다 |
| `TickScheduler` | `DisplayTickScheduler` (`Task` 루프) | `ManualTickScheduler` — `fire()` 를 부를 때만 tick |

### 이렇게 한 이유

실제 시간을 기다리지 않고 다음을 **결정적으로** 재현할 수 있다.

시작 직후 / 1분 경과 / 종료 직전 / 종료 시점 / 종료 초과 / background 복귀.

특히 **background 는 "tick 을 부르지 않는 것"으로 그대로 재현된다.**
`ManualTickScheduler` 가 자동으로 돌지 않기 때문에, 시계만 앞당기고 `fire()` 를
부르지 않으면 앱이 suspend 된 상황과 동일하다.

10분짜리 쉼의 종료를 검증하는 데 10분이 걸리지 않는다. CI 에서 전체 타이머 테스트가 1초 안에 끝난다.

### 의존 방향

```
RestSessionView → RestFlowCoordinator → RestTimerService → Clock / TickScheduler
```

`RestTimerService` 는 UI 를 알지 못한다. `Foundation` 만 import 한다.
뷰는 `Timer` 도 `Date` 도 직접 다루지 않고 `scenePhase` 변화를 coordinator 에 전달만 한다.
`scripts/verify_repo.py` 가 `Services/` 의 `SwiftUI`·`UIKit` import 를 차단해 이 방향을 강제한다.

