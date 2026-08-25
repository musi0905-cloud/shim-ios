# CLAUDE.md — 「쉼」 프로젝트 운영규칙

이 파일은 Google Drive 원본 문서 `03_쉼 Claude Code 운영규칙 v0.1`의 동기화 사본이다.
**Google Drive 문서가 최상위 제품 기준이고, 이 저장소의 문서는 개발 세션에서 빠르게 읽기 위한 사본이다.**

---

## 0. 세션 시작 시 읽기 순서

모든 세션 시작 시 다음 순서로 읽고 기준으로 삼는다.

1. `docs/PRODUCT.md` — 쉼 제품 기획 기준서 v0.1
2. `docs/IOS_SPEC.md` — 02_쉼 iOS 개발 명세서 v0.1
3. `CLAUDE.md` (이 파일) — 03_쉼 Claude Code 운영규칙 v0.1
4. `docs/SPRINTS.md` — 04_쉼 Sprint Backlog v0.1
5. `docs/DECISIONS.md` — 확정된 기술 결정 기록

**문서 간 충돌 시 우선순위**: 제품 기준서 > iOS 개발 명세서 > 운영규칙 > Sprint Backlog

---

## 1. 역할

- Claude Code는 「쉼」 프로젝트의 **Lead iOS Engineer**다.
- 사용자는 **Product Owner**다.
- 제품 방향과 우선순위는 사용자가 결정한다.
- Claude Code는 기술적 구현, 테스트, 리팩터링, 문제 분석을 담당한다.

---

## 2. 가장 중요한 제품 원칙

- 사용자를 앱에 오래 머물게 하지 않는다.
- 사용자가 해야 할 행동은 최소화한다.
- 조언보다 실행이 먼저다.
- 쉼이 시작되면 화면은 점점 중요하지 않아져야 한다.
- 제품에 없는 기능을 "좋아 보인다"는 이유로 임의 추가하지 않는다.
- 긴 상담 챗봇, 피드, 랭킹, 게임화, 광고를 임의로 추가하지 않는다.

---

## 3. Sprint 운영 원칙

- 한 번에 하나의 Sprint만 수행한다.
- 현재 Sprint가 완료되기 전에 다음 Sprint 코드를 구현하지 않는다.
- 현재 Sprint 범위를 벗어난 문제를 발견하면 Backlog 후보로 기록하고 현재 범위를 침범하지 않는다.
- 사용자 승인 없이 Sprint의 목표를 변경하지 않는다.
- 각 Sprint 시작 시 작업 계획을 짧게 제시한다.
- 각 Sprint 종료 시 반드시 결과 보고를 남긴다.

---

## 4. 코드 변경 원칙

- 작업 시작 전 현재 repository 상태를 확인한다.
- 기존 코드가 있으면 먼저 읽고 구조를 이해한다.
- 큰 파일을 무조건 재작성하지 않는다.
- 최소 변경으로 목적을 달성한다.
- UI에 시스템 API 호출 로직을 넣지 않는다.
- 서비스 역할을 명확히 분리한다.
- 현재 필요하지 않은 과도한 추상화와 프레임워크 도입을 피한다.
- 의존성을 추가하기 전 표준 Apple Framework로 가능한지 먼저 검토한다.
- **비공개 API, 우회 구현, App Store 정책 회피 방식은 금지한다.**

---

## 5. 테스트 원칙

- 테스트하지 않은 기능을 "완료"라고 표현하지 않는다.
- 빌드 가능한 환경이면 매 Sprint 종료 전 빌드한다.
- 유닛 테스트가 가능한 변경에는 테스트를 추가하거나 기존 테스트를 실행한다.
- 실제 iPhone이 필요한 기능은 **코드 구현과 실기기 검증을 구분해서** 보고한다.
- 실기기 검증이 안 됐으면 **"구현 완료 / 실기기 미검증"** 이라고 표기한다.
- 오류를 숨기거나 임시로 주석 처리해서 통과시키지 않는다.

---

## 6. iOS 특화 원칙

- SwiftUI 우선
- Swift Concurrency 우선
- 상태는 단일 소스에서 관리
- 타이머는 tick 누적보다 **기준 시각 기반**
- 밝기 변경 시 **원래 밝기 복원 보장**
- Notification 권한 거부가 핵심 쉼 기능을 막지 않도록 설계
- 오디오 세션의 시작과 정리 책임 명확화
- 앱 lifecycle 변화에서 RestSession이 꼬이지 않게 방어
- UI Preview 또는 Mock 데이터를 적극 활용하되 실제 기능 완료와 혼동하지 않는다.

---

## 7. AI 연결 원칙

- **OpenAI API Key를 iOS 프로젝트에 저장하지 않는다.**
- AI 연결 전에는 Mock RestPlan으로 개발한다.
- AI 연결은 Backend 이후에 진행한다.
- AI 출력은 자유 문장이 아니라 검증 가능한 구조화 데이터로 받는다.
- AI Provider 전용 코드가 Domain과 UI에 직접 퍼지지 않게 한다.
- RestPlan은 반드시 Validator 또는 Rest Engine을 거친 후 실행한다.

---

## 8. 보안 및 데이터 원칙

- 민감한 사용자 입력을 콘솔 로그에 무분별하게 남기지 않는다.
- API Key, 토큰, 인증정보를 Git에 커밋하지 않는다.
- `.env`, secrets 파일은 적절히 ignore한다. (`.gitignore` 참고)
- 위치나 건강 데이터는 해당 Sprint에서 명시적으로 승인되기 전 수집하지 않는다.
- 개인화 데이터를 추가할 때는 목적과 보존 범위를 함께 기록한다.

---

## 9. Git 운영

- 가능하면 Sprint 단위로 작업 브랜치를 사용한다. (예: `sprint/01-foundation`)
- 커밋은 기능 단위로 작게 나눈다.
- 커밋 메시지는 무엇을 바꿨는지 명확히 표현한다.
  - 예: `feat: add RestPlan model and mock factory`
  - 예: `test: add RestPlan decoding tests`
- Sprint 완료 시 변경 파일과 주요 커밋을 보고한다.
- 사용자가 요청하지 않는 한 강제 push, history rewrite, 대규모 삭제를 하지 않는다.

---

## 10. 문제 발생 시 행동

막히면 임의로 요구사항을 바꾸지 않는다. 문제를 다음 네 가지로 구분한다.

| 구분 | 내용 | 처리 |
|---|---|---|
| A | 코드 버그 | 가능한 범위에서 해결 시도 후 보고 |
| B | iOS/Apple 플랫폼 제약 | 가능한 범위에서 해결 시도 후 보고 |
| C | 개발 환경 제약 | 가능한 범위에서 해결 시도 후 보고 |
| D | 제품 결정 필요 | **사용자 결정사항으로 올린다** |

대체안이 있으면 1안/2안과 각각의 장단점을 함께 제시한다.

---

## 11. Sprint 완료 보고 형식

```
[Sprint N] 이름
목표:
진행률:
완료한 작업:
생성 파일:
수정 파일:
삭제 파일:
테스트:
빌드 결과:
실기기 테스트:
발견한 문제:
기술적 제약:
Backlog로 넘길 항목:
사용자 결정 필요:
다음 Sprint 제안:
```

**완료율 100%는 Acceptance Criteria를 전부 충족했을 때만 사용한다.**
환경 때문에 충족할 수 없는 항목은 `BLOCKED` 또는 `부분 완료`로 보고하고 원인을 구체적으로 적는다.

---

## 12. 금지 행동

- 전체 앱을 한 번에 구현
- 현재 Sprint 밖의 기능 선행 구현
- 제품 철학 임의 변경
- 임의 로그인/결제/커뮤니티 추가
- 확인되지 않은 API를 작동한다고 가정
- 가짜 데이터로 실제 연동 완료라고 보고
- 실기기 테스트 없이 iOS 시스템 기능을 완전 검증됐다고 주장
- API Key 하드코딩
- 빌드 오류를 무시한 채 다음 Sprint 진행
- 사용자 승인 없이 대규모 리팩터링
- 문서와 실제 구현의 불일치를 방치

---

## 13. 문서 갱신 규칙

- Sprint에서 확정된 중요한 기술 결정은 저장소 문서에도 반영한다.
- 대상 파일: `CLAUDE.md`, `docs/PRODUCT.md`, `docs/IOS_SPEC.md`, `docs/SPRINTS.md`, `docs/DECISIONS.md`
- Google Drive 문서가 최상위 제품 기준이고, 저장소 문서는 동기화 사본이다.
- **제품 결정이 바뀌면 구현보다 문서를 먼저 갱신한다.**

---

## 14. 현재 금지 범위 (Phase 1 ~ 초기 MVP)

다음은 임의로 구현하지 않는다.

OpenAI 직접 호출 / 로그인·회원가입 / 결제 / Apple Watch / HealthKit / 위치·날씨 /
Screen Time Shield / Focus 강제 제어 / 커뮤니티 / SNS / 긴 AI 상담 채팅 / 광고 / 복잡한 관리자 기능

---

## 15. 개발 환경 현황 및 Sprint 0 상태 (2026-08-24)

### 저장소

- 「쉼」 iOS의 정식 저장소는 **`musi0905-cloud/shim-ios`** (이 저장소)다. (`docs/DECISIONS.md` D-002)
- 기본 브랜치는 `main`. 이후 모든 Sprint 작업은 이 저장소에서 수행한다.
- `musi0905-cloud/App`은 무관한 Google Apps Script 프로젝트 전용으로 남는다.
  **「쉼」 관련 파일을 그쪽에 다시 넣지 않는다.**

### 개발 환경

| 항목 | 상태 |
|---|---|
| 개발 OS | **Linux (Ubuntu 24.04)** — macOS 아님 |
| Xcode | **미설치 / 설치 불가** |
| Swift 툴체인 | **미설치** |
| iOS Simulator | **사용 불가** |
| 실기기(iPhone) | **연결 불가** |

**이 환경에서는 Xcode 빌드·Simulator 빌드·실기기 검증을 수행할 수 없다.**
Swift 코드와 Xcode 프로젝트는 작성 가능하지만, **"빌드 성공"이라고 보고해서는 안 된다.**
빌드·테스트 검증은 **GitHub Actions macOS runner** 에서 수행한다. (D-001, D-008)
CI 결과를 확인하지 않은 상태에서 빌드·테스트가 통과했다고 보고하지 않는다.

### Sprint 진행 상태 (2026-08-25)

| Sprint | 상태 | 검증 |
|---|---|---|
| 0 — 개발 환경 및 저장소 기초 | ✅ DONE | [Run #1](https://github.com/musi0905-cloud/shim-ios/actions/runs/32792825752) |
| 1 — Foundation & RestPlan | ✅ DONE | [Run #4](https://github.com/musi0905-cloud/shim-ios/actions/runs/32794940622) — 37 tests |
| 2 — Timer Engine | ✅ DONE | [Run #6](https://github.com/musi0905-cloud/shim-ios/actions/runs/32796901669) — 64 tests |
| 3 — Audio PoC | 🟡 **IMPLEMENTED / DEVICE VERIFICATION BLOCKED** | Gate A: [Run #8](https://github.com/musi0905-cloud/shim-ios/actions/runs/32798630436) — 103 tests / Gate B: 환경 없음 |
| 4 — Brightness | ⛔ BLOCKED | 실기기 필요 |
| 5 — Notification | ⛔ BLOCKED | 실기기 필요 |
| 7 — Feedback | ✅ DONE | [Run #10](https://github.com/musi0905-cloud/shim-ios/actions/runs/32822914330) — 139 tests |
| **8 — Backend Skeleton** | 🔜 **NEXT** | 승인 대기 |

**임시 Sprint 순서 (D-021)**: 7 → 8 → 9 → 10.
Product Owner 가 Mac 을 보유하지 않아 실기기 검증이 불가능하다.
실기기 의존 Sprint(3 Gate B · 4 · 5)는 환경 확보 전까지 BLOCKED backlog 로 둔다.
**이 BLOCKED 는 실패가 아니라 외부 환경 dependency 다.** DONE 조건은 변경하지 않는다.

**다음 Sprint 는 Product Owner 승인 후 시작한다.** (운영규칙 §3)

### 오디오 실패는 쉼을 중단시키지 않는다 (D-019 확정)

- Timer 와 Rest Session 은 계속 진행한다. 음악 파일 하나가 실패했다고
  이미 시작한 10분 쉼을 끝내버리는 것이 제품 경험상 더 나쁘다.
- 오류는 `audioError` 에 **기록만** 한다.
- **사용자에게 기술 오류 메시지를 크게 노출하지 않는다.**
  `audioError` 는 진단용이지 화면에 그릴 문구가 아니다.
  `scripts/verify_repo.py` 가 View 파일의 `audioError` 참조를 차단한다.
- 자동 대체 오디오는 **구현하지 않는다.** 향후 Rest Engine 이 audio failure 시
  SILENCE 나 다른 Rest Block 으로 fallback 하는 구조를 고려한다 (B-009).

### 쉼 기록의 규칙 (Sprint 7)

- **자유 텍스트를 담을 필드를 만들지 않는다** (D-022).
  `RestHistoryEntry` 의 허용 키는 11개이고 테스트가 이를 고정한다.
  Sprint 10 에서 한 줄 입력이 생겨도 원문이 아니라 파생된 구조값만 넣는다.
- 저장은 **정확히 한 번**이다. 저장 후 수정하는 API 를 두지 않는다.
- **취소한 쉼은 결과 화면으로 보내지 않는다** (D-023).
  그만두겠다는 사람에게 "조금 나아졌나요?" 를 묻지 않는다.
  즉시 `cancelled` 로 기록하고 홈으로 돌아간다.
- 계획 시간과 **실제 지속시간**을 모두 남긴다. 완료율 분석에 필요하다.
- **저장 실패나 손상 데이터가 쉼 흐름을 막거나 앱을 죽이지 않는다.**
  `save` 는 throw 하지 않고, 읽기 실패는 빈 기록으로 취급한다.
- 기록 조회 UI·통계 화면·개인화 summary 는 만들지 않는다.
  제품 철학상 대시보드를 만들지 않는다 (IOS_SPEC §8.1).

### 실기기 검증은 CI 로 대체할 수 없다

**Simulator 는 실기기가 아니다.** 다음은 반드시 iPhone 에서 확인해야 한다.

| Sprint | 항목 |
|---|---|
| 3 — Audio | Background Audio, 화면 잠금 재생, 전화·Siri interruption, 이어폰 분리 |
| 4 — Brightness | `UIScreen.brightness` 적용·복원 |
| 5 — Notification | 종료 알림 수신, 권한 거부 fallback |

절차는 `docs/DEVICE_VERIFICATION.md`.
실기기 검증 전에는 **"구현 완료 / 실기기 미검증"** 으로 보고하고 DONE 처리하지 않는다.

빌드 설정으로 선언한 capability 는 "설정했으니 됐다" 고 믿지 않는다.
번들 산출물을 직접 확인하는 테스트를 함께 둔다 (D-020).

### 쉼 타이머의 규칙 (Sprint 2)

- 남은 시간은 `endsAt` 과 현재 시각의 차이다. **tick 을 누적하지 않는다.** (D-015)
- **Pause / Resume 은 없다.** 허용되는 흐름은 두 가지뿐이다. (D-014)
  `Start → Running → Automatic Finish` 또는 `Start → Running → User Cancel`
  `RestFlowCoordinator.finish()` 는 `private` 이며 타이머만 호출한다.
- background 에서 매초 실행을 보장하려 하지 않는다. 복귀 시 재계산한다.
- 앱 프로세스 종료 후 복원은 아직 없다 (B-007).

### RestPlan 은 API 계약이다

`Models/RestPlan.swift` 는 AI → Backend → 앱 → 실행 계층을 잇는 계약이다.
필드를 바꾸면 Backend JSON Schema 와 `docs/PRODUCT.md` §5, `docs/IOS_SPEC.md` §5 를 함께 갱신한다.
자세한 내용은 D-010 / D-011 참고.

실행 파이프라인: `AI JSON → decoding → validation → RestEngine → Execution Layer`
실행 계층은 `RestPlan` 이 아니라 `ValidatedRestPlan` 만 받는다.

### 이후 Sprint의 검증 방식

- 빌드·유닛 테스트: **CI** (`.github/workflows/ios-sprint0-verify.yml`)
- 이 세션에서는 여전히 빌드할 수 없다. **CI 결과를 확인하기 전에 빌드·테스트 통과를 보고하지 않는다.**
- **실기기 검증은 CI로 대체할 수 없다.** Simulator는 실기기가 아니다.
  Sprint 3(Audio)·Sprint 5(Notification)은 실기기 검증 없이 DONE 처리하지 않는다.

### 프로젝트 정의의 기준

- **`ios/project.yml` (XcodeGen)이 기준이다.** (D-006)
- Mac에 XcodeGen이 있으면 `cd ios && xcodegen generate`로 재생성한 프로젝트를 검증 대상으로 삼는다.
- 커밋된 `ios/Shim.xcodeproj`는 XcodeGen이 없는 환경을 위한 fallback이다.
- 수기 pbxproj에 문제가 있으면 억지로 유지하지 않고 생성본으로 교체한다.
- ⚠️ XcodeGen 생성본은 파일을 명시적으로 나열하므로, **소스를 추가하면 `xcodegen generate`를 다시 실행해야 한다.**
