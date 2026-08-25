//
//  AudioService.swift
//  Shim
//
//  쉼 중 재생할 오디오의 경계.
//
//  의존 방향 (docs/IOS_SPEC.md §4.1):
//
//      RestPlan → ValidatedRestPlan → RestFlowCoordinator
//                                        ↓
//                                   AudioService
//                                        ↓
//                              AVAudioSession / AVAudioPlayer
//
//  **SwiftUI View 는 AVFoundation 을 직접 호출하지 않는다.**
//  이 파일도 AVFoundation 을 import 하지 않는다. 프로토콜과 오류 타입만 둔다.
//  실제 프레임워크 접촉은 AudioPlatform.swift 가 담당한다.
//
//  ── Pause 에 대한 구분 (중요) ────────────────────────────────────────
//
//  사용자 UX 의 Pause 는 없다. 쉼 시간을 사용자가 관리하게 하지 않는다 (D-014).
//  그래서 이 프로토콜에도 `pause()` 가 없다.
//
//  다만 전화·Siri 같은 **OS interruption** 에 대응하려면 내부적으로 멈췄다
//  다시 트는 동작이 필요하다. 그것은 구현체 내부 상태로만 존재하며
//  사용자에게 노출되지 않는다. (D-017)
//

import Foundation

@MainActor
protocol AudioService: AnyObject {
    /// 지금 소리가 나고 있는지.
    ///
    /// 무음 모드(`.silence`)이거나 interruption 으로 멈춘 동안에는 false 다.
    var isPlaying: Bool { get }

    /// 재생 준비. 리소스를 찾고 플레이어를 만든다.
    ///
    /// - Throws: `AudioServiceError`
    func prepare(mode: AudioMode) async throws

    /// 재생 시작. 이미 재생 중이면 아무 일도 하지 않는다.
    ///
    /// - Throws: `AudioServiceError`
    func play() async throws

    /// 정지하고 자원을 정리한다. 여러 번 불러도 안전하다.
    ///
    /// 쉼이 정상 종료되든 사용자가 취소하든 반드시 호출되어야 한다.
    func stop()
}

/// 오디오 실패 사유.
///
/// 오디오가 실패해도 앱이 죽지 않는다. 호출부가 이 오류를 받아 명시적으로
/// 처리한다. 쉼 전체를 중단할지 여부는 자동으로 결정하지 않는다 — D-019.
enum AudioServiceError: Error, Equatable {
    /// 이 모드에 해당하는 음원을 아직 지원하지 않는다.
    case unsupportedMode(AudioMode)
    /// 음원 파일을 번들에서 찾지 못했다.
    case resourceNotFound(name: String)
    /// 플레이어를 만들지 못했다. (파일 손상, 형식 미지원 등)
    case playerCreationFailed(reason: String)
    /// `prepareToPlay()` 가 실패했다.
    case preparationFailed
    /// 재생 시작이 실패했다.
    case playbackStartFailed
    /// AVAudioSession 활성화가 실패했다.
    case sessionActivationFailed(reason: String)
    /// 준비 없이 재생을 시도했다.
    case notPrepared
}

extension AudioServiceError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .unsupportedMode(mode):
            return "오디오 모드 '\(mode.rawValue)' 를 아직 지원하지 않습니다."
        case let .resourceNotFound(name):
            return "음원 '\(name)' 을 찾을 수 없습니다."
        case let .playerCreationFailed(reason):
            return "오디오 플레이어를 만들지 못했습니다. (\(reason))"
        case .preparationFailed:
            return "오디오 재생 준비에 실패했습니다."
        case .playbackStartFailed:
            return "오디오 재생을 시작하지 못했습니다."
        case let .sessionActivationFailed(reason):
            return "오디오 세션을 활성화하지 못했습니다. (\(reason))"
        case .notPrepared:
            return "오디오가 준비되지 않았습니다."
        }
    }
}
