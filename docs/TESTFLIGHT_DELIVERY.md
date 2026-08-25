# Sprint 7.5 — TestFlight Delivery PoC (조사·설계)

> **목표**: 기능 개발이 아니다.
> `GitHub → cloud macOS build → signing/archive → App Store Connect → TestFlight → PO iPhone`
> 경로가 **실제로 가능한지** 검증한다.
>
> 이 문서는 **조사·설계 결과**다. 이 단계에서는 Apple 계정 가입·결제·
> App Store Connect 변경을 **수행하지 않는다.**

이 경로가 뚫리면 막혀 있는 **Sprint 3 Gate B · Sprint 4 Brightness · Sprint 5 Notification**
을 다시 실기기 기준으로 진행할 수 있다 (D-021).

---

## 1. 결론 요약

| 항목 | 결과 |
|---|---|
| Mac 없이 TestFlight 배포가 가능한가 | **가능성이 높다.** 다만 확인해야 할 blocker 1건이 있다 |
| 추천 경로 | **GitHub Actions** (조사 결과 PO 초기 추천과 다름 — §5 참고) |
| 필수 비용 | Apple Developer Program **US$99/년** |
| PO 직접 작업 | 계정 가입, App Store Connect 앱 레코드 생성, 인증서 다운로드, Secrets 등록 |
| Claude Code 자동화 | CSR 생성, 워크플로 작성, 빌드·서명·업로드 스크립트 |
| 최대 blocker | **Xcode Cloud 는 Xcode 15+ 를 요구조건으로 명시한다** (§5.3) |

---

## 2. 필요한 Apple 계정·권한·식별자

### 2.1 계정

| 항목 | 필요 여부 | 비고 |
|---|---|---|
| Apple ID | 필수 | PO 기존 계정 사용 가능 |
| **Apple Developer Program 가입** | **필수** | 연 US$99. TestFlight 배포의 전제조건 |
| D-U-N-S 번호 | 개인 가입은 **불필요** | 법인(Organization) 가입 시에만 필요 |
| App Store Connect 접근 | 자동 부여 | 가입 시 Account Holder 역할 |

> 개인(Individual) 자격으로 가입하면 Team Name 이 개인 이름이 된다.
> 나중에 법인으로 전환하려면 별도 절차가 필요하다. 지금은 개인으로 충분하다.

가입은 웹 또는 iPhone 의 **Apple Developer 앱**으로 가능하다. **Mac 이 필요하지 않다.**

### 2.2 권한 (App Store Connect 역할)

| 역할 | 용도 |
|---|---|
| Account Holder | PO 본인. 가입자에게 자동 부여 |
| App Manager | 앱 레코드 생성·관리 |
| Developer | 빌드 업로드 |

혼자 쓰는 단계에서는 Account Holder 하나로 전부 처리된다.

### 2.3 식별자

| 식별자 | 값 | 결정 상태 |
|---|---|---|
| Bundle ID | `com.shimapp.Shim` (현재) | ⚠️ **재검토 필요** — §3 |
| Team ID | 가입 후 발급 (10자 영숫자) | 가입 후 확인 |
| App Store Connect App ID | 앱 레코드 생성 시 발급 | 미생성 |
| App Store Connect API Key ID / Issuer ID | 웹에서 생성 | 미생성 |

---

## 3. Bundle Identifier 검토 — **PO 결정 필요**

현재 값: **`com.shimapp.Shim`**

### 문제

1. **역DNS 관례 위반** — `shimapp.com` 도메인을 보유하지 않는다.
   Apple 이 소유를 강제하지는 않지만 관례상 자신이 통제하는 도메인을 뒤집어 쓴다.
2. **전역 유일성** — Bundle ID 는 **App Store Connect 전체에서 유일**해야 한다.
   `com.shimapp.Shim` 처럼 일반적인 이름은 이미 등록돼 있을 수 있다.
3. **사실상 영구** — 앱 레코드를 만들고 나면 Bundle ID 를 바꿀 수 없다.
   등록된 Bundle ID 는 삭제·재사용도 어렵다. **지금 확정해야 한다.**

### 선택지

| 안 | 값 | 장점 | 단점 |
|---|---|---|---|
| **1안 (추천)** | `com.musi0905.shim` | 계정 식별자 기반이라 충돌 가능성이 매우 낮다 | 도메인 소유와 무관 |
| 2안 | `com.<보유도메인>.shim` | 관례에 가장 부합 | 도메인을 보유해야 한다 |
| 3안 | 현행 유지 `com.shimapp.Shim` | 코드 변경 없음 | 이미 등록돼 있으면 가입 후에 막힌다 |

> 확정 전까지 코드를 바꾸지 않는다. PO 가 고르면 `ios/project.yml` 과
> `ios/Shim.xcodeproj/project.pbxproj` 두 곳을 함께 바꾼다.
> `scripts/verify_repo.py` 가 두 값의 일치를 검사한다.

---

## 4. App Store Connect 앱 레코드에 필요한 값

앱 레코드는 **PO 가 웹에서 직접 생성**한다. Mac 이 필요하지 않다.

| 필드 | 제안 값 | 비고 |
|---|---|---|
| **Platform** | iOS | |
| **App Name** | ⚠️ **PO 결정 필요** | **App Store Connect 전체에서 유일해야 한다.** "쉼" 단독은 이미 사용 중일 가능성이 있다. `쉼 - 나를 위한 시간` 같은 형태를 권한다. TestFlight 내부 테스트에만 쓸 이름이며 나중에 변경 가능하다 |
| **Primary Language** | 한국어 (Korean) | 제품 문서와 UI 문구가 한국어다 |
| **Bundle ID** | §3 에서 확정한 값 | 먼저 Developer 포털에 등록해야 목록에 나타난다 |
| **SKU** | `SHIM-IOS-001` | 내부 식별자. 공개되지 않는다. 계정 내 유일하면 된다 |
| **User Access** | Full Access | 혼자 쓰는 단계 |

---

## 5. 배포 경로 비교 — GitHub Actions vs Xcode Cloud

### 5.1 공통 전제

두 경로 모두 다음이 필요하다.

- Apple Developer Program 가입 (US$99/년)
- App Store Connect 앱 레코드
- Distribution 인증서 + App Store provisioning profile
- TestFlight 내부 테스트 그룹에 PO 계정 추가

### 5.2 GitHub Actions 경로

```
Claude Code (Linux)  →  GitHub  →  macOS runner
                                      ↓  xcodebuild archive
                                      ↓  codesign (Secrets 의 인증서)
                                      ↓  xcrun altool / notarytool upload
                                   App Store Connect  →  TestFlight  →  iPhone
```

**Mac 이 필요한 작업은 전부 macOS runner 가 대신한다.** PO 는 브라우저만 있으면 된다.

인증서도 Mac 없이 만들 수 있다. Keychain Access 대신 **OpenSSL 로 CSR 을 생성**해
Developer 포털에 올리고, 내려받은 `.cer` 를 `.p12` 로 변환한다.
이 방식은 널리 쓰이며 여러 CI 서비스가 같은 절차를 안내한다.

| | |
|---|---|
| ✅ | Mac 이 **전혀** 필요 없다 |
| ✅ | 이미 동작하는 CI(Run #1~#10)를 그대로 확장한다 |
| ✅ | 전 과정이 저장소의 코드로 남아 재현·검토 가능하다 |
| ⚠️ | 인증서·프로파일·API Key 관리를 직접 설계해야 한다 |
| ⚠️ | private 저장소에서 **macOS 분당 10배** 과금 (§7) |

### 5.3 Xcode Cloud 경로 — ⚠️ **핵심 blocker**

Apple 공식 요구사항 문서(*Setting up your project to use Xcode Cloud*)는
**Xcode 15.0 이상**과 Apple Developer Program 멤버십을 요구조건으로 명시한다.
**Xcode 는 macOS 전용이다.**

즉 *"서명 부담이 적어 Mac 없는 PO 에게 유리하다"* 는 기대와 달리,
**Xcode Cloud 를 시작하려면 Mac 이 필요할 가능성이 높다.**

| | |
|---|---|
| ✅ | Apple 공식 스택. Archive→TestFlight 가 매끄럽다 |
| ✅ | 서명 인증서·프로파일을 Apple 이 자동 관리한다 |
| ✅ | 멤버십에 **월 25 compute hours** 포함 |
| ❌ | **요구조건에 Xcode 15+ 가 명시돼 있다 — Mac 없이 온보딩 가능한지 불확실** |
| ⚠️ | 설정이 저장소 밖(Apple 서버)에 있어 버전 관리가 안 된다 |

> **확인 방법 (무료, 가입 후 즉시)**
> App Store Connect 웹에 로그인해 앱 레코드의 **Xcode Cloud** 탭에서
> Xcode 없이 워크플로를 새로 만들 수 있는지 확인한다.
> 만들 수 있으면 Xcode Cloud 가 더 나은 선택일 수 있다.
> 만들 수 없으면 **GitHub Actions 가 유일하게 실행 가능한 경로**다.

### 5.4 추천 — **GitHub Actions**

조사 결과 PO 의 초기 추천(Xcode Cloud)과 다른 결론에 도달했다.

**이유**

1. **확실성** — Xcode Cloud 는 Xcode 를 요구조건으로 명시한다. GitHub Actions 는
   Mac 이 필요한 모든 작업을 runner 가 처리하므로 Mac 없이 확실히 동작한다.
2. **이미 검증된 기반** — 이 저장소의 CI 가 macOS runner 에서 Xcode 26.6 으로
   빌드·테스트를 10회 성공했다. archive·upload 단계만 얹으면 된다.
3. **재현성** — 전 과정이 저장소의 YAML 로 남는다. Xcode Cloud 설정은 Apple 서버에만 있다.

**PO 지적이 옳은 부분**: 서명 인증서·프로파일·Secrets 관리를 직접 설계해야 하는
운영 부담은 실재한다. 다만 **일회성 설정**이고, 그 대가로 Mac 의존이 사라진다.

> Xcode Cloud 를 완전히 배제하지는 않는다. §5.3 의 확인에서 웹 온보딩이 가능하다면
> 다시 비교할 가치가 있다.

---

## 6. 자동 서명 구조 (GitHub Actions 기준)

### 6.1 비밀정보는 저장소에 넣지 않는다

**GitHub Secrets(암호화 저장)에만 둔다.**

| Secret | 내용 | 생성 위치 |
|---|---|---|
| `APP_STORE_CONNECT_KEY_ID` | API Key ID | App Store Connect 웹 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID | App Store Connect 웹 |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `.p8` 파일 내용 | App Store Connect 웹 (**1회만 다운로드 가능**) |
| `DISTRIBUTION_CERT_P12_BASE64` | `.p12` 를 base64 인코딩 | OpenSSL 로 변환 |
| `DISTRIBUTION_CERT_PASSWORD` | `.p12` 비밀번호 | PO 가 정함 |

`.gitignore` 는 이미 `.p12` · `.mobileprovision` · `AuthKey_*.p8` · `*.certSigningRequest`
를 차단한다 (Sprint 0). `scripts/verify_repo.py` 의 시크릿 스캔도 매 CI 마다 돈다.

> ⚠️ `.p8` 개인키는 **생성 직후 한 번만** 내려받을 수 있다. 잃어버리면 폐기하고 다시 만든다.

### 6.2 인증서 생성 절차 (Mac 불필요)

| # | 작업 | 수행자 |
|---|---|---|
| 1 | OpenSSL 로 개인키와 CSR 생성 | **Claude Code** (Linux) |
| 2 | CSR 을 Developer 포털에 업로드 → Apple Distribution 인증서 발급 | **PO** (웹) |
| 3 | `.cer` 다운로드 | **PO** |
| 4 | `.cer` + 개인키 → `.p12` 변환, base64 인코딩 | **Claude Code** |
| 5 | GitHub Secrets 에 등록 | **PO** (웹) |

> 개인키는 저장소에 커밋하지 않는다. 세션 임시 디렉터리에서 만들고
> PO 에게 안전하게 전달한 뒤 폐기한다. 전달 방법은 별도 협의한다.

### 6.3 빌드 워크플로 설계 (초안 — 아직 만들지 않음)

```
1. Checkout
2. XcodeGen generate                    (기존 CI 와 동일)
3. Secrets 의 .p12 를 임시 keychain 에 import
4. App Store Connect API 로 provisioning profile 발급/다운로드
5. xcodebuild archive -configuration Release
6. xcodebuild -exportArchive (method: app-store-connect)
7. .ipa 를 App Store Connect 에 업로드
8. keychain 삭제 (성공·실패 무관)
```

트리거는 **수동(`workflow_dispatch`) 또는 태그 push** 로 둔다.
매 커밋마다 TestFlight 빌드를 올리면 과금과 빌드 번호가 낭비된다.

빌드 번호(`CURRENT_PROJECT_VERSION`)는 매 업로드마다 증가해야 한다.
`github.run_number` 를 쓰면 자동으로 해결된다.

---

## 7. 예상 비용

| 항목 | 금액 | 비고 |
|---|---|---|
| **Apple Developer Program** | **US$99 / 년** | 필수. 지역별 환산 청구 |
| GitHub Actions (현재 private 저장소) | 무료 한도 내 가능 | 아래 계산 |
| Xcode Cloud | 멤버십에 월 25시간 포함 | 초과 시 별도 구독 |

### GitHub Actions 과금 계산

private 저장소에서 **macOS 는 분당 10배**로 차감된다.
Free 플랜 월 2,000분 → 실질 **macOS 약 200분**.

| 작업 | 실제 시간 | 차감 | 월 한도 대비 |
|---|---|---|---|
| 현재 검증 CI (Run #10 기준) | 약 4분 | 40분 | 약 50회 |
| TestFlight archive + upload (추정) | 12~20분 | 120~200분 | **약 10회** |

**월 10회 정도의 TestFlight 빌드는 무료 한도로 가능하다.** 부족하면:

- **저장소를 public 으로 전환** → Actions 무료 (⚠️ PO 결정 사항. 현재 코드에 비밀정보는 없다)
- 검증 CI 를 PR 에서만 돌리도록 축소
- 유료 플랜 또는 분당 과금

> 요금·한도는 변동된다. 실제 도입 전 GitHub 청구 설정에서 현재 값을 확인한다.

---

## 8. TestFlight 내부 테스트 절차

**내부 테스트(Internal Testing)** 를 쓴다. 외부 테스트와 달리 **Beta App Review 가 없어**
업로드 후 처리만 끝나면 바로 설치할 수 있다.

| # | 작업 | 수행자 |
|---|---|---|
| 1 | App Store Connect → TestFlight → Internal Testing 그룹 생성 | PO |
| 2 | 그룹에 PO 본인 계정 추가 | PO |
| 3 | 빌드 업로드 (CI 자동) | Claude Code |
| 4 | 수출 규정 준수(Export Compliance) 질문 응답 | PO — 암호화 미사용이면 즉시 통과 |
| 5 | iPhone 에 **TestFlight 앱** 설치 (App Store 에서 무료) | PO |
| 6 | 초대 수락 → 설치 | PO |

> 내부 테스터는 App Store Connect 사용자여야 한다. 최대 100명.
> 업로드된 빌드는 **90일 후 만료**된다. 만료되면 새 빌드를 올린다.
> 개발자 계정 직접 설치(7일 만료)보다 유효기간이 훨씬 길다.

---

## 9. 역할 분담

### PO 가 직접 해야 하는 최소 작업

Claude Code 가 대신할 수 없는 것들이다. 계정·결제·법적 동의가 걸린 작업이다.

| # | 작업 | 예상 시간 |
|---|---|---|
| 1 | Apple Developer Program 가입 및 결제 | 가입 신청 10분 + **승인 대기 24~48시간** |
| 2 | Bundle ID 확정 및 Developer 포털 등록 | 5분 |
| 3 | App Store Connect 앱 레코드 생성 | 10분 |
| 4 | CSR 업로드 → 인증서 다운로드 | 5분 |
| 5 | App Store Connect API Key 생성 및 `.p8` 다운로드 | 5분 |
| 6 | GitHub Secrets 5건 등록 | 10분 |
| 7 | TestFlight 내부 테스트 그룹 생성 및 본인 추가 | 5분 |
| 8 | iPhone 에 TestFlight 앱 설치 | 2분 |
| 9 | 수출 규정 준수 질문 응답 | 1분 |

**합계 약 1시간** + 가입 승인 대기.

### Claude Code 가 자동화할 수 있는 작업

| # | 작업 |
|---|---|
| 1 | OpenSSL 로 개인키·CSR 생성 |
| 2 | `.cer` → `.p12` 변환, base64 인코딩 |
| 3 | 릴리스 워크플로 작성 (archive·서명·업로드) |
| 4 | 빌드 번호 자동 증가 |
| 5 | Bundle ID 변경을 `project.yml` 과 `pbxproj` 양쪽에 반영 |
| 6 | 업로드 실패 로그 분석 및 수정 |
| 7 | 비밀정보가 저장소에 들어가지 않았는지 검증 |

---

## 10. 예상 blocker

| # | blocker | 가능성 | 대응 |
|---|---|---|---|
| 1 | **Xcode Cloud 가 Mac 없이 온보딩 불가** | 높음 | GitHub Actions 로 진행 (§5.4) |
| 2 | Developer Program 가입 승인 지연·거부 | 중 | 개인 가입은 보통 24~48시간. 신원 확인 요구 가능 |
| 3 | Bundle ID 가 이미 사용 중 | 중 | §3 의 1안으로 충돌 회피 |
| 4 | App Name 이 이미 사용 중 | 중 | 이름 변경. 내부 테스트 단계에서는 자유롭게 바꿀 수 있다 |
| 5 | 서명 설정 오류 (프로파일·인증서 불일치) | **높음** | 첫 시도에 대개 실패한다. CI 로그로 반복 수정. 시간이 걸릴 수 있다 |
| 6 | macOS 무료 분 소진 | 중 | §7 의 완화책 |
| 7 | `.p8` 키 분실 (1회만 다운로드) | 중 | 즉시 Secrets 등록. 잃으면 폐기 후 재발급 |
| 8 | 업로드 빌드 처리 지연 | 낮음 | 보통 수분~1시간 |
| 9 | 저장소가 private 이라 Xcode Cloud 접근 설정 필요 | 중 | GitHub Actions 경로에서는 해당 없음 |

> **5번이 가장 현실적인 위험이다.** 서명은 처음에 거의 반드시 한 번은 실패한다.
> Sprint 3 의 `UIBackgroundModes` 처럼 CI 로그를 보고 고치는 과정이 필요하다.

---

## 11. Sprint 7.5 Acceptance Criteria

Sprint 3 과 같이 **두 Gate 로 나눈다.** 비용이 발생하는 시점을 명확히 가르기 위해서다.

### Gate A — 조사·설계 (비용 없음) ✅ 이 문서로 완료

| # | 기준 | 상태 |
|---|---|---|
| A-1 | 필요한 Apple 계정·권한·식별자 목록 정리 | ✅ §2 |
| A-2 | Bundle Identifier 검토 및 선택지 제시 | ✅ §3 — **PO 결정 대기** |
| A-3 | 비밀정보를 저장소에 커밋하지 않는 구조 설계 | ✅ §6.1 |
| A-4 | App Store Connect 앱 레코드 필요 값 문서화 | ✅ §4 |
| A-5 | GitHub Actions 로 archive/upload 가능한지 검토 | ✅ §5.2 |
| A-6 | GitHub Actions vs Xcode Cloud 비교 | ✅ §5 |
| A-7 | Mac 없이 관리하기 쉬운 쪽 추천 | ✅ §5.4 |
| A-8 | 가입·결제·Apple 계정 변경을 수행하지 않음 | ✅ 수행하지 않음 |
| A-9 | 앱 기능 변경 없음 | ✅ 코드 변경 0 |
| A-10 | 예상 비용·blocker 정리 | ✅ §7, §10 |

### Gate B — 실제 배포 (PO 승인·결제 후)

| # | 기준 |
|---|---|
| B-1 | Apple Developer Program 가입 완료 |
| B-2 | App Store Connect 앱 레코드 생성 완료 |
| B-3 | CI 가 archive·서명·업로드에 성공한다 |
| B-4 | 빌드가 TestFlight 에 나타난다 |
| B-5 | **PO 의 iPhone 에 설치되어 실행된다** |
| B-6 | 저장소에 비밀정보가 커밋되지 않았음을 확인한다 |

**B-5 가 성공하면** Sprint 3 Gate B → Sprint 4 → Sprint 5 를 다시 실기기 기준으로 진행한다.

---

## 12. PO 결정이 필요한 항목

| # | 결정 | 기본값 / 추천 |
|---|---|---|
| 1 | **Apple Developer Program 가입 여부 (US$99/년)** | 없으면 이 경로 전체가 불가능하다 |
| 2 | **Bundle ID** | `com.musi0905.shim` (§3 1안) |
| 3 | **App Name** | `쉼 - 나를 위한 시간` 등. 유일해야 한다 |
| 4 | 배포 경로 | **GitHub Actions** (§5.4) |
| 5 | 저장소 public 전환 여부 | 현재 private. 무료 분이 부족할 때만 고려 |

---

## 참고 자료

- [Xcode Cloud Overview](https://developer.apple.com/xcode-cloud/)
- [Setting up your project to use Xcode Cloud (요구사항)](https://developer.apple.com/documentation/xcode/requirements-for-using-xcode-cloud)
- [Distributing Your Xcode Cloud Builds Through TestFlight](https://developer.apple.com/documentation/xcode/distributing-your-xcode-cloud-builds-through-testflight)
- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/)
- [Apple Developer Program 가입](https://developer.apple.com/help/account/membership/program-enrollment)
- [GitHub Actions 요금](https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/)

> ⚠️ Apple 과 GitHub 의 요금·한도·요구사항은 변동된다.
> 이 문서의 수치는 **2026-08 기준 조사값**이며, 실제 결제 전에 공식 페이지에서 다시 확인해야 한다.
