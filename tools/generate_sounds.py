#!/usr/bin/env python3
"""assets/sounds/ 아래 알람음·수면유도음 WAV 파일을 순수 파이썬(사인파 합성)으로 생성한다.
외부 리소스 없이 재생성 가능하도록 저장소에 스크립트를 포함해 둔다.

사용법: python3 tools/generate_sounds.py
"""
import math
import struct
import wave
import os

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def note_freq(semitones_from_a4: float) -> float:
    return 440.0 * (2 ** (semitones_from_a4 / 12))


# 간단한 음이름 -> A4 기준 반음 오프셋
NOTES = {
    "C4": -9, "D4": -7, "E4": -5, "F4": -4, "G4": -2, "A4": 0, "B4": 2,
    "C5": 3, "D5": 5, "E5": 7, "F5": 8, "G5": 10, "A5": 12,
}


def envelope(i: int, n: int, attack: int, release: int) -> float:
    if i < attack:
        return i / max(attack, 1)
    if i > n - release:
        return max(0.0, (n - i) / max(release, 1))
    return 1.0


def synth_tone(freq: float, duration: float, volume: float = 0.35,
               wave_shape: str = "sine", attack=200, release=400):
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        if wave_shape == "sine":
            v = math.sin(2 * math.pi * freq * t)
        elif wave_shape == "square":
            v = 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0
        else:
            v = math.sin(2 * math.pi * freq * t)
        v *= envelope(i, n, attack, release) * volume
        samples.append(v)
    return samples


def silence(duration: float):
    return [0.0] * int(SAMPLE_RATE * duration)


def mix_sequential(parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write_wav(path: str, samples, loop_fade=True):
    if loop_fade:
        # 루프 재생 시 이음매가 튀지 않도록 시작/끝을 아주 짧게 페이드.
        fade = min(400, len(samples) // 10)
        for i in range(fade):
            samples[i] *= i / fade
            samples[-(i + 1)] *= i / fade
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        wf.writeframes(frames)
    print(f"wrote {path} ({len(samples) / SAMPLE_RATE:.1f}s)")


def build_sleep_calm():
    # 느리고 부드러운 패드 화음 루프 (수면유도 노래).
    chord = [NOTES["C4"], NOTES["E4"], NOTES["G4"]]
    parts = []
    for _ in range(2):
        layer = [0.0] * int(SAMPLE_RATE * 6.0)
        for semi in chord:
            tone = synth_tone(note_freq(semi), 6.0, volume=0.12,
                               wave_shape="sine", attack=2000, release=3000)
            layer = [a + b for a, b in zip(layer, tone)]
        parts.append(layer)
    return mix_sequential(parts)


def build_alarm_classic():
    beep = synth_tone(880, 0.18, volume=0.5, wave_shape="square", attack=20, release=40)
    gap = silence(0.12)
    pattern = mix_sequential([beep, gap, beep, gap, beep, silence(0.4)])
    return pattern * 2


def build_alarm_melody1():
    seq = ["C5", "E5", "G5", "C5", "G5", "E5", "C5"]
    parts = []
    for note in seq:
        parts.append(synth_tone(note_freq(NOTES[note]), 0.28, volume=0.4,
                                 wave_shape="sine", attack=30, release=80))
        parts.append(silence(0.03))
    parts.append(silence(0.3))
    return mix_sequential(parts)


def build_alarm_melody2():
    seq = ["G4", "A4", "B4", "C5", "B4", "A4", "G4", "D5"]
    parts = []
    for note in seq:
        parts.append(synth_tone(note_freq(NOTES[note]), 0.22, volume=0.42,
                                 wave_shape="square", attack=15, release=60))
        parts.append(silence(0.02))
    parts.append(silence(0.35))
    return mix_sequential(parts)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUT_DIR, "sleep_calm.wav"), build_sleep_calm())
    write_wav(os.path.join(OUT_DIR, "alarm_classic.wav"), build_alarm_classic())
    write_wav(os.path.join(OUT_DIR, "alarm_melody1.wav"), build_alarm_melody1())
    write_wav(os.path.join(OUT_DIR, "alarm_melody2.wav"), build_alarm_melody2())


if __name__ == "__main__":
    main()
