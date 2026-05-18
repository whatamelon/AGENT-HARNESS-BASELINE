#!/usr/bin/env python3
# bgm-gen.py — mac-setup 인트로용 8비트 칩튠 BGM 생성기.
# 결정적(deterministic). 8bit unsigned PCM WAV 직접 합성 → 외부 의존/escaping 없음.
# 사용: python3 bgm-gen.py <out.wav> [duration_sec=10]
import sys, wave, math

out = sys.argv[1]
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 10.0
SR = 22050  # 낮은 SR + 사각파 + 8bit 양자화 = 콘솔 도트게임 전자음 느낌


def sq(t, f):  # square wave
    return 1.0 if math.sin(2 * math.pi * f * t) >= 0 else -1.0


# C 펜타토닉 아르페지오 리드 + 2스텝 베이스 (Hz)
LEAD = [523, 659, 784, 1047, 784, 659, 587, 698, 880, 1175, 880, 698]
BASS = [131, 131, 196, 196]  # C3 C3 G3 G3
NOTE = 0.135   # 리드 1음 길이(s)
BNOTE = 0.54   # 베이스 1음 길이(s)

frames = bytearray()
for i in range(int(SR * dur)):
    t = i / SR
    li = int(t / NOTE) % len(LEAD)
    bi = int(t / BNOTE) % len(BASS)
    env = max(0.0, 1.0 - ((t % NOTE) / NOTE) * 0.6)  # plucky 감쇠
    s = 0.55 * env * sq(t, LEAD[li]) + 0.30 * sq(t, BASS[bi])
    v = int(128 + 110 * max(-1.0, min(1.0, s)))      # 8bit unsigned, 중심 128
    frames.append(max(0, min(255, v)))

w = wave.open(out, "wb")
w.setnchannels(1)
w.setsampwidth(1)
w.setframerate(SR)
w.writeframes(bytes(frames))
w.close()
