//
//  AudioPlatform.swift
//  Shim
//
//  AVFoundation 과 실제로 맞닿는 얇은 층.
//
//  이 파일만 AVFoundation 을 안다. `DefaultAudioService` 는 아래 프로토콜에만
//  의존하므로 테스트에서 실제 소리를 내지 않고 검증할 수 있다.
//  (Sprint 2 에서 Clock 을 주입한 것과 같은 방식이다.)
//

import Foundation
import AVFoundation

// MARK: - 플레이어

/// AVAudioPlayer 가 제공하는 것 중 우리가 쓰는 것만 추린 인터페이스.
protocol AudioPlayerEngine: AnyObject {
    var isPlaying: Bool { get }
    var numberOfLoops: Int { get set }
    var volume: Float { get set }

    func prepareToPlay() -> Bool
    func play() -> Bool
    func pause()
    func stop()
}

extension AVAudioPlayer: AudioPlayerEngine {}

/// 모드에 맞는 플레이어를 만들어 준다.
@MainActor
protocol AudioPlayerProviding {
    /// - Returns: 재생할 것이 없으면 `nil` (무음 모드). 오류가 아니다.
    /// - Throws: `AudioServiceError`
    func makePlayer(for mode: AudioMode) throws -> AudioPlayerEngine?
}

/// 앱 번들의 음원으로 `AVAudioPlayer` 를 만든다.
@MainActor
struct BundleAudioPlayerProvider: AudioPlayerProviding {

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// 모드별 음원 파일 이름.
    ///
    /// ⚠️ PoC 단계라 소리가 나는 모드는 전부 같은 테스트 음원을 쓴다.
    ///    모드별로 다른 음원을 고르는 것은 제품 사운드를 정한 뒤의 일이다.
    ///    (docs/DECISIONS.md D-018)
    static func resourceName(for mode: AudioMode) -> String? {
        switch mode {
        case .calmAcoustic, .natureSound:
            return "test_ambient"
        case .silence:
            return nil   // 재생할 것이 없다
        }
    }

    func makePlayer(for mode: AudioMode) throws -> AudioPlayerEngine? {
        guard let name = Self.resourceName(for: mode) else {
            return nil
        }
        guard let url = bundle.url(forResource: name, withExtension: "wav") else {
            throw AudioServiceError.resourceNotFound(name: name)
        }
        do {
            return try AVAudioPlayer(contentsOf: url)
        } catch {
            throw AudioServiceError.playerCreationFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - 세션

/// AVAudioSession 설정과 시스템 이벤트 전달.
@MainActor
protocol AudioSessionConfiguring: AnyObject {
    /// 전화·Siri 등으로 오디오가 중단될 때.
    var onInterruptionBegan: (() -> Void)? { get set }
    /// interruption 이 끝났을 때. `shouldResume` 은 시스템이 재개를 권하는지다.
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)? { get set }
    /// 이어폰이 빠지는 등 출력 경로가 사라졌을 때.
    var onRouteDeviceUnavailable: (() -> Void)? { get set }

    /// 재생용 세션을 활성화한다.
    func activatePlayback() throws
    /// 세션을 비활성화한다.
    func deactivate() throws
}

/// 실제 `AVAudioSession` 구현.
///
/// 정책 (Sprint 3 PoC):
///     Category  .playback
///     Mode      .default
///     Background Audio capability  ON (UIBackgroundModes = audio)
///
/// `.playback` 이라야 앱이 background 로 가거나 화면이 잠겨도 재생이 이어진다.
/// 이것이 "휴대폰을 내려놓고 있어도 쉼은 계속된다" 의 전제다.
@MainActor
final class AVAudioSessionConfigurator: AudioSessionConfiguring {

    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)?
    var onRouteDeviceUnavailable: (() -> Void)?

    private let session: AVAudioSession
    private var observers: [NSObjectProtocol] = []

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
        registerObservers()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func activatePlayback() throws {
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    func deactivate() throws {
        // 다른 앱이 재생을 이어받을 수 있도록 알린다.
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: 시스템 이벤트

    private func registerObservers() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleInterruption(notification)
            }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleRouteChange(notification)
            }
        })
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            onInterruptionEnded?(options.contains(.shouldResume))
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
        else { return }

        // 이어폰이 빠졌다. 스피커로 갑자기 소리가 터져 나오면 안 된다.
        if reason == .oldDeviceUnavailable {
            onRouteDeviceUnavailable?()
        }
    }
}
