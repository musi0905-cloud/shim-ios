//
//  RestPlanEnums.swift
//  Shim
//
//  RestPlan 을 구성하는 어휘(vocabulary).
//
//  이 enum 들은 AI 가 반환할 Structured Output 의 허용값이자 앱 실행 계층의
//  분기 기준이다. 즉 **API 계약의 일부**다.
//
//  값을 추가·변경할 때의 규칙:
//    - 현재 명세에 없는 값을 임의로 만들지 않는다. 각 case 는 아래 주석에
//      출처(docs/PRODUCT.md 또는 docs/IOS_SPEC.md)를 남긴다.
//    - rawValue 는 snake_case 다. AI/Backend JSON 이 snake_case 이기 때문이다
//      (docs/PRODUCT.md §5).
//    - 값을 추가하면 Backend 의 JSON Schema 와 docs 를 함께 갱신한다.
//
//  알 수 없는 값이 들어오면 decoding 이 실패한다(throw). 이는 의도된 동작이다.
//  근거는 docs/DECISIONS.md D-010 참고.
//

import Foundation

/// 쉼의 유형.
///
/// - Note: 현재 명세에 등장하는 값은 `environment_reset` 하나다
///   (docs/PRODUCT.md §5 예시, docs/IOS_SPEC.md §5 예시).
///   전체 어휘 확정은 Product Owner 결정 사항이다 — docs/DECISIONS.md D-011.
enum RestType: String, Codable, CaseIterable, Equatable {
    /// 지금의 환경에서 잠시 벗어나 환경을 재설정한다. (PRODUCT.md §5)
    case environmentReset = "environment_reset"
}

/// 쉼 중 재생할 오디오 유형.
enum AudioMode: String, Codable, CaseIterable, Equatable {
    /// 잔잔한 어쿠스틱. (PRODUCT.md §5 예시 `calm_acoustic`)
    case calmAcoustic = "calm_acoustic"
    /// 자연음. (PRODUCT.md §6 Rest Blocks `NATURE_SOUND`)
    case natureSound = "nature_sound"
    /// 소리 없음. (PRODUCT.md §6 Rest Blocks `SILENCE`)
    case silence
}

/// 쉼 중 권유할 움직임.
enum MovementType: String, Codable, CaseIterable, Equatable {
    /// 천천히 걷기. (PRODUCT.md §5 예시, IOS_SPEC.md §5 예시)
    case slowWalk = "slow_walk"
    /// 가벼운 스트레칭. (PRODUCT.md §6 Rest Blocks `STRETCH`)
    case stretch
    /// 움직이지 않음. 실내·이동 불가 상황용. (PRODUCT.md §6 규칙)
    case none
}

/// 쉼 중 화면 표시 방식.
enum ScreenMode: String, Codable, CaseIterable, Equatable {
    /// 남은 시간과 한 문장만 보여준다. (IOS_SPEC.md §8.2)
    case minimal
    /// 화면을 어둡게 유지한다. (PRODUCT.md §6 Rest Blocks `DARK_SCREEN`)
    case dark
}
