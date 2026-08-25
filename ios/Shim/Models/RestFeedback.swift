//
//  RestFeedback.swift
//  Shim
//
//  쉼이 끝난 뒤 받는 단 한 번의 응답.
//
//  docs/IOS_SPEC.md §8.3 — "질문은 한 번만 한다. 조금 나아졌나요?"
//
//  ⚠️ 화면에 표시할 문구는 여기 두지 않는다. 이 타입은 저장·전송되는
//     계약값이고, 문구는 표현 계층의 몫이다. 문구가 바뀌어도 저장된
//     데이터의 의미는 변하지 않아야 한다.
//

import Foundation

enum RestFeedback: String, Codable, CaseIterable, Equatable {
    /// 조금 나아졌어요
    case better
    /// 그대로예요
    case same
    /// 더 불편해요
    case worse
}
