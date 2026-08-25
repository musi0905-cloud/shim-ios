#!/usr/bin/env python3
"""
PoC 검증용 테스트 오디오 생성기.

⚠️ 여기서 만드는 음원은 **제품용 콘텐츠가 아니다.**
   오디오 실행 파이프라인(AVAudioSession / AVAudioPlayer / Background Audio)이
   실제로 성립하는지 검증하기 위한 합성 톤이다.
   제품 사운드와 Apple Music 연동은 훨씬 뒤 Sprint 에서 결정한다.

외부에서 음원을 내려받지 않는 이유:
   라이선스 출처가 불분명한 파일을 저장소에 넣지 않는다. 직접 생성하면
   저작권 문제가 원천적으로 없다. (docs/DECISIONS.md D-018)

특징:
   - 30초, 모노, 22.05 kHz, 16-bit PCM WAV (약 1.3 MB)
   - 낮은 볼륨 (피크 약 -18 dBFS)
   - loop 이음매 없음: 모든 부분음의 주파수가 30초 안에 정수 번 진동하도록
     골라서 파일 끝과 처음이 위상까지 맞는다. AVAudioPlayer 가 무한 반복해도
     '툭' 하는 소리가 나지 않는다.

사용법:
    python3 scripts/generate_test_audio.py
    → ios/Shim/Resources/Audio/test_ambient.wav

표준 라이브러리만 쓴다. numpy 같은 의존성을 추가하지 않는다.
"""

from __future__ import annotations

import math
import os
import struct
import wave

SAMPLE_RATE = 22_050
DURATION_SECONDS = 30
CHANNELS = 1
SAMPLE_WIDTH = 2  # 16-bit

OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "ios", "Shim", "Resources", "Audio", "test_ambient.wav",
)

# 부분음: (30초 동안의 진동 횟수, 진폭)
# 횟수를 정수로 두면 파일 끝에서 위상이 정확히 처음과 맞는다 → 이음매 없는 반복.
PARTIALS = [
    (30 * 110, 0.60),   # 110 Hz  기음
    (30 * 165, 0.22),   # 165 Hz  5도
    (30 * 220, 0.14),   # 220 Hz  옥타브
    (30 * 330, 0.06),   # 330 Hz  옅은 배음
]

# 아주 느린 음량 흔들림. 30초 동안 정수 번 반복해야 이음매가 유지된다.
TREMOLO_CYCLES = 3
TREMOLO_DEPTH = 0.18

PEAK = 0.125  # 최종 피크 진폭. 낮게 잡는다.


def render() -> bytes:
    total = SAMPLE_RATE * DURATION_SECONDS
    partial_norm = sum(amp for _, amp in PARTIALS)
    frames = bytearray()

    for index in range(total):
        position = index / total  # 0.0 ~ 1.0

        value = 0.0
        for cycles, amplitude in PARTIALS:
            value += amplitude * math.sin(2.0 * math.pi * cycles * position)
        value /= partial_norm

        tremolo = 1.0 - TREMOLO_DEPTH * (
            0.5 - 0.5 * math.cos(2.0 * math.pi * TREMOLO_CYCLES * position)
        )
        value *= tremolo * PEAK

        sample = int(max(-1.0, min(1.0, value)) * 32767)
        frames += struct.pack("<h", sample)

    return bytes(frames)


def main() -> int:
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    frames = render()

    with wave.open(OUTPUT, "wb") as handle:
        handle.setnchannels(CHANNELS)
        handle.setsampwidth(SAMPLE_WIDTH)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)

    size_kb = os.path.getsize(OUTPUT) / 1024
    print(f"생성: {OUTPUT}")
    print(f"  {DURATION_SECONDS}초 / {SAMPLE_RATE} Hz / "
          f"{'mono' if CHANNELS == 1 else 'stereo'} / {SAMPLE_WIDTH * 8}-bit")
    print(f"  {size_kb:.0f} KB")

    # loop 이음매 확인: 첫 샘플과 마지막 다음 샘플의 위상이 맞아야 한다.
    first = struct.unpack("<h", frames[0:2])[0]
    last = struct.unpack("<h", frames[-2:])[0]
    print(f"  loop 이음매: 첫 샘플 {first}, 마지막 샘플 {last} "
          f"(차이 {abs(first - last)} — 작을수록 매끄럽다)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
