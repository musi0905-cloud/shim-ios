# 실기기 검증 절차

CI 는 실기기를 대체할 수 없다. Simulator 는 실기기가 아니다.
`docs/SPRINTS.md` 에서 실기기 검증을 요구하는 Sprint 는 이 문서의 절차를 따른다.

| Sprint | 검증 항목 | 상태 |
|---|---|---|
| 3B — Audio | Background Audio / 화면 잠금 / interruption | ⏳ **대기** |
| 5B — Notification | 종료 알림 수신 / 권한 거부 fallback | (Sprint 5 이후) |

---

> ⚠️ **현재 이 절차를 실행할 수 없다 (2026-08-25).**
> Product Owner 는 iPhone 은 보유하고 있으나 **Mac 이 없다.**
> iPhone 에 개발 중인 앱을 설치하려면 Xcode 가 필요하고 Xcode 는 macOS 전용이다.
> Sprint 3 Gate B · Sprint 4 · Sprint 5 는 환경 확보 전까지 BLOCKED 다 (D-021).
> Mac 없이 설치하는 경로로 TestFlight 가 있다 — B-010, Product Owner 결정 대기.

## 준비 — iPhone 에 앱 설치하기

Simulator 빌드에는 Apple Developer 계정이 필요 없지만 **실기기 설치에는 필요하다.**
무료 개인 Apple ID 로 충분하다. 유료 프로그램(연 $99)은 TestFlight·App Store 배포부터 필요하다. (D-004)

```bash
git clone https://github.com/musi0905-cloud/shim-ios.git
cd shim-ios/ios
brew install xcodegen        # 미설치 시
xcodegen generate
open Shim.xcodeproj
```

Xcode 에서:

1. **Signing & Capabilities** 탭 → Team 을 본인 Apple ID 로 선택
   - "Add an Account…" 로 Apple ID 를 등록하면 Personal Team 이 생긴다
   - Bundle Identifier 가 중복이라고 나오면 `com.shimapp.Shim` 뒤에 본인 식별자를 덧붙인다
2. **Background Modes** 에 **Audio, AirPlay, and Picture in Picture** 가 켜져 있는지 확인
   - `ios/Shim-Info.plist` 로 이미 선언돼 있으므로 체크되어 있어야 한다 (D-020)
   - 꺼져 있으면 background 재생이 안 된다. 그 자체가 검증 실패다
3. iPhone 을 USB 로 연결하고 상단 기기 선택기에서 고른다
4. ⌘R 로 실행

**처음 실행 시 iPhone 이 "신뢰할 수 없는 개발자" 라고 거부하면**
설정 → 일반 → VPN 및 기기 관리 → 본인 Apple ID → 신뢰

> ⚠️ 무료 계정으로 설치한 앱은 **7일 후 만료**된다. 만료되면 Xcode 에서 다시 실행한다.

⚠️ Team 을 선택하면 Xcode 가 `project.pbxproj` 에 Team ID 를 기록한다.
**커밋 전에 `git diff` 로 확인하고 되돌린다.** 저장소에는 빈 값을 유지한다. (D-004)

```bash
git diff ios/Shim.xcodeproj/project.pbxproj    # DEVELOPMENT_TEAM 이 채워졌는지
git checkout -- ios/Shim.xcodeproj             # 되돌리기
```

---

## Sprint 3B — Audio 실기기 검증

`ios/Shim/Resources/Audio/test_ambient.wav` 는 낮은 볼륨의 합성 톤이다.
**기기 볼륨을 어느 정도 올려야 들린다.** 무음 스위치도 확인한다.
`.playback` 카테고리라 무음 스위치가 켜져 있어도 소리가 나는 것이 정상이다.

검증은 두 단계로 나눈다. **1차 6개가 통과하면 Background Audio 의 핵심 제품 가설이 검증된 것이다.**
다만 Sprint 3 의 최종 DONE 조건은 **10개 전부**다. 기록 일관성을 위해 2차까지 마친 뒤 DONE 처리한다.

### 1차 — 핵심 6개 (Background Audio 제품 가설)

이 6개가 통과하면 "사용자는 휴대폰을 내려놓고, 앱이 대신 환경을 만들어준다" 가 실제로 성립한다.

| # | 검증 항목 | 방법 | 기대 결과 | 결과 |
|---|---|---|---|---|
| 1 | **foreground 재생** | 홈에서 "10분 쉼 시작" | 곧바로 잔잔한 톤이 재생된다 | ⬜ |
| 2 | **홈 화면으로 나가도 지속** | 재생 중 홈 버튼/제스처로 홈 화면 이동 | **소리가 끊기지 않는다** | ⬜ |
| 3 | **화면 잠가도 지속** | 전원 버튼으로 화면 잠금 | **소리가 계속 난다** | ⬜ |
| 4 | **앱 복귀 시 정상** | 잠금 해제 후 앱으로 복귀 | 남은 시간이 실제 경과분만큼 줄어 있다. 소리는 계속 난다 | ⬜ |
| 5 | **정상 종료 시 정지** | 남은 시간이 0이 될 때까지 대기 | 결과 화면으로 넘어가며 **소리가 즉시 멈춘다** | ⬜ |
| 6 | **취소 시 정지** | 재생 중 "쉼 그만하기" | **소리가 즉시 멈춘다** | ⬜ |

> 2번과 3번이 이번 Sprint 의 핵심이다. 여기서 소리가 끊기면
> `UIBackgroundModes` 나 `AVAudioSession` 정책 문제다 (D-017, D-020).

### 2차 — robustness 4개

시스템이 끼어들었을 때 비정상 상태가 남지 않는지 본다.
1차보다 급하지 않지만 DONE 조건에는 포함된다.

| # | 검증 항목 | 방법 | 기대 결과 | 결과 |
|---|---|---|---|---|
| 7 | **전화 interruption** | 재생 중 다른 기기로 전화 걸기 → 받기 → 끊기 | 통화 중 소리가 멈추고, 통화 종료 후 다시 재생되거나 깔끔히 멈춰 있다. **소리가 겹치거나 유령처럼 남지 않는다** | ⬜ |
| 8 | **Siri interruption** | 재생 중 Siri 호출 후 종료 | 7번과 같다 | ⬜ |
| 9 | **이어폰 분리** | 이어폰으로 재생 중 뽑기 | **스피커로 갑자기 터져 나오지 않는다.** 멈춘다 | ⬜ |
| 10 | **다른 앱 오디오와의 충돌** | 음악 앱 재생 중 쉼 시작 | 동작을 그대로 기록한다 (음악이 멈추는지, 섞이는지) | ⬜ |

### 짧게 확인하려면

10분을 기다리기 어렵다. `MockRestPlanFactory.defaultPlan()` 의
`durationMinutes` 를 1~2 로 잠시 바꾸면 종료 동작을 빨리 확인할 수 있다.
**확인 후 원래대로 되돌린다.** 커밋하지 않는다.

### 결과 보고

아래를 알려주면 Sprint 3 상태를 갱신한다.

1. **1차 6개**의 통과/실패 — 이것만으로도 중간 보고가 가능하다
2. 실패한 항목의 실제 동작 (무엇이 기대와 달랐는지)
3. iPhone 모델과 iOS 버전
4. 2차 4개를 진행했다면 그 결과. 특히 10번의 관찰 내용

**1차 6개 통과** → 핵심 제품 가설 검증 완료. 2차를 이어서 진행한다.
**1차 + 2차 10개 전부 통과** → **Sprint 3 DONE**.
하나라도 실패하면 원인을 분석해 수정하고 다시 검증한다.

### 검증할 수 없는 경우

iPhone 이나 Apple ID 가 없어 검증이 불가능하면 그 사실을 알려주면 된다.
Sprint 3 은 `IMPLEMENTED / DEVICE VERIFICATION BLOCKED` 로 남기고,
Sprint 3 에 의존하지 않는 Sprint 로 넘어간다.

**Sprint 3 에 의존하지 않는 후보** (오디오 없이 검증 가능):

| Sprint | 내용 | 실기기 필요 여부 |
|---|---|---|
| 7 — Feedback & Local Personalization | 피드백 저장, 로컬 기록 | ❌ 불필요. CI 로 완결 |
| 8 — Backend Skeleton | 서버 구조, Mock AI Provider | ❌ 불필요 |
| 4 — Brightness | 화면 밝기 제어·복원 | ⚠️ 필요 (Simulator 에서 `UIScreen.brightness` 가 실기기와 다르게 동작) |
| 5 — Local Notification | 종료 알림 | ⚠️ 필요 |

> Sprint 4·5 도 실기기가 필요하므로, 실기기 검증이 장기간 불가능하다면
> **Sprint 7 → 8 순서를 먼저 진행**하는 편이 낫다.
> 이 순서 변경은 Product Owner 결정 사항이다.
