#!/usr/bin/env python3
"""Writes the onboarding's background music into Podrida/Resources.

Original loops synthesized here, so there's nothing to license. Four styles:

  guitar     Nylon-guitar arpeggio over Am - G - F - E, marimba melody, soft bass and shaker
  musicbox   A music-box waltz in C, bells over a broken-chord accompaniment
  jazz       Café jazz: electric-piano comping on ii - V - I, walking bass, brushes, vibes melody
  chiptune   8-bit: pulse-wave lead, fast arpeggios, triangle bass and noise drums

The reverb is applied circularly, so the tail of the last bar rings into the first and the file
loops without a seam. Needs numpy and macOS's afconvert.

  python3 ios/tools/make_music.py                         # the app's tracks (APP_TRACKS)
  python3 ios/tools/make_music.py --style guitar --out x.caf
"""
import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RESOURCES = Path(__file__).resolve().parent.parent / "Podrida" / "Resources"
# The files the app plays (OnboardingMusic.Track), and the style each one is.
APP_TRACKS = {"onboarding-jazz": "jazz", "onboarding-chiptune": "chiptune"}
RATE = 44100
NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
rng = np.random.default_rng(7)


def note(name):
    pitch, octave = name[:-1], int(name[-1])
    return 440 * 2 ** ((NAMES[pitch] + 12 * (octave + 1) - 69) / 12)


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


# --- Instruments ---------------------------------------------------------------------------------

def pluck(freq, seconds=2.4):
    """Nylon-string guitar: harmonics that die faster the higher they are, with a soft attack."""
    t = times(seconds)
    tone = np.zeros_like(t)
    for k in range(1, 12):
        if freq * k > 9000:
            break
        stiffness = 1 + 0.0007 * k * k
        tone += (1 / k ** 1.25) * np.sin(2 * np.pi * freq * k * stiffness * t) * np.exp(-t * (1.6 + 1.1 * k))
    return tone * np.minimum(1, t / 0.004)


def marimba(freq, seconds=1.6):
    t = times(seconds)
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-t * 3.2)
    tone += 0.35 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 14)
    tone += 0.12 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t * 30)
    return tone * np.minimum(1, t / 0.002)


def bell(freq, seconds=2.2):
    """Music-box tine: a pure fundamental with the metal's inharmonic partials ringing off quickly."""
    t = times(seconds)
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-t * 2.2)
    tone += 0.45 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 6)
    tone += 0.2 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t * 14)
    tone += 0.08 * np.sin(2 * np.pi * freq * 8.9 * t) * np.exp(-t * 30)
    return tone * np.minimum(1, t / 0.001)


def epiano(freq, seconds=2.0):
    """Rhodes-style electric piano: warm body, a bright tine at the attack, slow tremolo."""
    t = times(seconds)
    body = np.sin(2 * np.pi * freq * t + 0.6 * np.sin(2 * np.pi * freq * t) * np.exp(-t * 4))
    tine = 0.18 * np.sin(2 * np.pi * freq * 7 * t) * np.exp(-t * 18)
    tremolo = 1 - 0.12 * (1 + np.sin(2 * np.pi * 4.5 * t)) / 2
    return (body * np.exp(-t * 1.3) + tine) * tremolo * np.minimum(1, t / 0.005)


def vibes(freq, seconds=2.4):
    t = times(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 8)
    motor = 1 - 0.3 * (1 + np.sin(2 * np.pi * 5.5 * t)) / 2
    return tone * np.exp(-t * 1.6) * motor * np.minimum(1, t / 0.002)


def bass(freq, seconds, decay=1.4):
    t = times(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    return tone * np.exp(-t * decay) * np.minimum(1, t / 0.01)


def upright(freq, seconds):
    """Upright bass: a thumpy attack and a round, quickly fading tone."""
    t = times(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 6)
    tone += 0.15 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-t * 12)
    return tone * np.exp(-t * 2.2) * np.minimum(1, t / 0.006)


def pulse(freq, seconds, duty=0.25, release=0.06):
    """Band-limited pulse wave, as on an old game console, with a short decay to a held level."""
    t = times(seconds)
    tone = np.zeros_like(t)
    k = 1
    while freq * k < 8000:
        tone += (np.sin(np.pi * k * duty) / k) * np.cos(2 * np.pi * freq * k * t)
        k += 1
    envelope = 0.7 + 0.3 * np.exp(-t * 12)
    envelope *= np.clip((seconds - t) / release, 0, 1)
    return tone / 2 * envelope * np.minimum(1, t / 0.002)


def triangle(freq, seconds):
    t = times(seconds)
    phase = (freq * t + 0.25) % 1  # start at zero, so notes don't click
    tone = 4 * np.abs(phase - 0.5) - 1
    return tone * np.clip((seconds - t) / 0.03, 0, 1)


def noise(seconds, decay, tilt=True):
    t = times(seconds)
    burst = rng.standard_normal(len(t))
    if tilt:
        burst = np.diff(burst, prepend=0)  # toward the highs
    return burst * np.exp(-t * decay) * np.minimum(1, t / 0.004)


def kick(seconds=0.25):
    t = times(seconds)
    sweep = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.exp(-t * 14)


# --- Mixing --------------------------------------------------------------------------------------

class Track:
    def __init__(self, bpm, beats):
        self.beat = 60 / bpm
        self.length = int(round(beats * self.beat * RATE))
        self.audio = np.zeros((2, self.length))

    def add(self, sound, beat, gain=1.0, pan=0.0):
        """Adds a sound at a beat, wrapping anything past the end back to the start."""
        start = int(round(beat * self.beat * RATE))
        left, right = gain * np.sqrt((1 - pan) / 2), gain * np.sqrt((1 + pan) / 2)
        idx = (start + np.arange(len(sound))) % self.length
        np.add.at(self.audio[0], idx, sound * left)
        np.add.at(self.audio[1], idx, sound * right)

    def finish(self, room=1.8, mix=0.28):
        """Circular convolution with a decaying-noise impulse, so the tail wraps into the loop start."""
        n = int(room * RATE)
        t = np.arange(n) / RATE
        wet = np.empty_like(self.audio)
        for channel in range(2):
            impulse = np.zeros(self.length)
            impulse[:n] = rng.standard_normal(n) * np.exp(-t * 6 / room)
            impulse[:int(0.012 * RATE)] = 0  # predelay
            impulse /= np.sqrt(np.sum(impulse ** 2))
            wet[channel] = np.fft.irfft(np.fft.rfft(self.audio[channel]) * np.fft.rfft(impulse), self.length)
        audio = (1 - mix) * self.audio + mix * wet
        return audio / (np.max(np.abs(audio)) / 0.7)  # about -3 dBFS


def humanize(amount=0.012):
    return rng.uniform(-amount, amount)


# --- Styles --------------------------------------------------------------------------------------

def guitar():
    track = Track(bpm=88, beats=32)
    chords = [
        ("A2", ["A3", "C4", "E4", "A4"]),
        ("G2", ["G3", "B3", "D4", "G4"]),
        ("F2", ["F3", "A3", "C4", "F4"]),
        ("E2", ["E3", "G#3", "B3", "E4"]),
    ]
    arpeggio = [0, 1, 2, 3, 2, 1, 2, 3]
    melody = [
        (4, 0, "E5", 1.5), (4, 1.5, "D5", 0.5), (4, 2, "C5", 1), (4, 3, "B4", 1),
        (5, 0, "D5", 1.5), (5, 1.5, "C5", 0.5), (5, 2, "B4", 2),
        (6, 0, "C5", 1), (6, 1, "A4", 1), (6, 2, "C5", 1), (6, 3, "F5", 1),
        (7, 0, "E5", 2), (7, 2, "G#4", 1), (7, 3, "B4", 1),
    ]
    for bar in range(8):
        root, tones = chords[bar % 4]
        b = bar * 4
        track.add(bass(note(root), 4 * track.beat), b, gain=0.55)
        track.add(bass(note(root), 2 * track.beat), b + 2.5, gain=0.25)
        for step, tone in enumerate(arpeggio):
            swing = 0.035 if step % 2 else 0
            accent = 1.0 if step == 0 else 0.72 + 0.1 * (step % 2 == 0)
            track.add(pluck(note(tones[tone])), b + step / 2 + swing + humanize(0.008), gain=0.3 * accent,
                      pan=-0.35 + 0.7 * tone / 3)
        for eighth in range(8):
            track.add(noise(0.09, 60), b + eighth / 2 + (0.035 if eighth % 2 else 0),
                      gain=0.05 if eighth % 2 else 0.028, pan=0.4)
    for bar, beat, name, length in melody:
        track.add(marimba(note(name), max(1.2, length * track.beat * 1.6)), bar * 4 + beat, gain=0.32, pan=-0.15)
    return track.finish()


def musicbox():
    track = Track(bpm=84, beats=8 * 3 * 2)  # a waltz: 16 bars of 3/4
    chords = [
        ("C4", ["E4", "G4", "C5"]), ("A3", ["E4", "A4", "C5"]), ("F3", ["F4", "A4", "C5"]), ("G3", ["D4", "G4", "B4"]),
        ("C4", ["E4", "G4", "C5"]), ("A3", ["E4", "A4", "C5"]), ("D4", ["F4", "A4", "D5"]), ("G3", ["F4", "B4", "D5"]),
    ]
    tune = [
        [("G5", 0, 1), ("E5", 1, 0.5), ("G5", 1.5, 0.5), ("C6", 2, 1)],
        [("A5", 0, 1), ("C6", 1, 0.5), ("A5", 1.5, 0.5), ("E5", 2, 1)],
        [("F5", 0, 1), ("A5", 1, 0.5), ("C6", 1.5, 0.5), ("A5", 2, 1)],
        [("D6", 0, 1.5), ("C6", 1.5, 0.5), ("B5", 2, 1)],
        [("E6", 0, 1), ("D6", 1, 1), ("C6", 2, 1)],
        [("C6", 0, 1), ("B5", 1, 0.5), ("A5", 1.5, 0.5), ("E5", 2, 1)],
        [("F5", 0, 0.5), ("A5", 0.5, 0.5), ("D6", 1, 1), ("C6", 2, 1)],
        [("B5", 0, 1), ("D6", 1, 1), ("G5", 2, 1)],
    ]
    for bar in range(16):
        root, tones = chords[bar % 8]
        b = bar * 3
        track.add(bell(note(root)), b + humanize(0.01), gain=0.34, pan=-0.2)
        for beat in (1, 2):
            for n, tone in enumerate(tones):
                track.add(bell(note(tone), 1.4), b + beat + n * 0.02 + humanize(0.008), gain=0.1, pan=-0.1 + 0.15 * n)
        # The second time round, a harmony an octave below joins the tune.
        for name, beat, _ in tune[bar % 8]:
            track.add(bell(note(name)), b + beat + humanize(0.01), gain=0.36, pan=0.15)
            if bar >= 8:
                lower = name[:-1] + str(int(name[-1]) - 1)
                track.add(bell(note(lower)), b + beat + 0.02, gain=0.14, pan=-0.25)
    return track.finish(room=2.4, mix=0.36)


def jazz():
    track = Track(bpm=100, beats=32)
    swing = 2 / 3  # the second eighth of each beat falls two-thirds of the way through it
    voicings = [
        ["F3", "A3", "C4", "E4"],     # Dm9
        ["F3", "B3", "E4", "A4"],     # G13
        ["E3", "G3", "B3", "D4"],     # Cmaj9
        ["G3", "C#4", "E4", "A#4"],   # A7(b9)
    ]
    walk = [
        ["D2", "F2", "A2", "G#2"], ["G2", "B2", "D3", "C#3"], ["C2", "E2", "G2", "A#2"], ["A2", "C#3", "E3", "D#3"],
        ["D2", "A2", "F2", "G#2"], ["G2", "D3", "B2", "C#3"], ["C2", "G2", "E2", "A#2"], ["A2", "E2", "C#3", "D#2"],
    ]
    melody = [
        (4, 0, "A4", 1), (4, 1, "C5", 1), (4, 2, "E5", 1.5), (4, 3 + swing, "D5", 1),
        (5, 1, "B4", 1), (5, 2, "F5", 1), (5, 3, "E5", 1),
        (6, 0, "E5", 1), (6, 1 + swing, "D5", 1), (6, 2, "B4", 1), (6, 3, "G4", 1),
        (7, 0, "A#4", 1), (7, 1, "C#5", 1), (7, 2, "E5", 2),
    ]
    for bar in range(8):
        b = bar * 4
        chord = voicings[bar % 4]
        # Comp on 1 and on the swung "and" of 2.
        for hit, gain in ((0, 0.16), (1 + swing, 0.12)):
            for n, tone in enumerate(chord):
                track.add(epiano(note(tone), 1.6), b + hit + n * 0.015 + humanize(0.01), gain=gain, pan=-0.25)
        for beat, tone in enumerate(walk[bar]):
            track.add(upright(note(tone), track.beat * 1.1), b + beat + humanize(0.008), gain=0.55, pan=0.05)
        # Brushes: the ride pattern (1, 2, "and" of 2, 3, 4, "and" of 4), plus a soft swish on 2 and 4.
        for beat in (0, 1, 1 + swing, 2, 3, 3 + swing):
            accent = 0.05 if beat in (1, 3) else 0.032
            track.add(noise(0.12, 32), b + beat + humanize(0.006), gain=accent, pan=0.35)
        for beat in (1, 3):
            track.add(noise(0.35, 8, tilt=False) * 0.4, b + beat - 0.1, gain=0.05, pan=0.3)
    for bar, beat, name, length in melody:
        track.add(vibes(note(name), max(1.4, length * track.beat * 2)), bar * 4 + beat + humanize(0.01), gain=0.2, pan=0.25)
    return track.finish(room=1.4, mix=0.22)


def chiptune():
    track = Track(bpm=140, beats=32)
    chords = [["C4", "E4", "G4"], ["B3", "D4", "G4"], ["C4", "E4", "A4"], ["C4", "F4", "A4"]]
    roots = ["C2", "G2", "A2", "F2"]
    tune = [
        ["E5", None, "G5", None, "C6", "B5", "G5", "E5"],
        ["D5", None, "G5", None, "B5", "A5", "G5", "D5"],
        ["C5", None, "E5", None, "A5", "G5", "E5", "C5"],
        ["F5", "E5", "F5", "A5", "G5", None, None, None],
        ["E5", "G5", "C6", "G5", "E6", "D6", "C6", "G5"],
        ["D5", "G5", "B5", "G5", "D6", "C6", "B5", "G5"],
        ["C5", "E5", "A5", "E5", "C6", "B5", "A5", "E5"],
        ["F5", None, "A5", None, "C6", None, "B5", None],
    ]
    step = track.beat / 2
    for bar in range(8):
        b = bar * 4
        chord = chords[bar % 4]
        for sixteenth in range(16):
            tone = chord[sixteenth % 3]
            track.add(pulse(note(tone), track.beat / 4, duty=0.125), b + sixteenth / 4, gain=0.07, pan=-0.3)
        root = note(roots[bar % 4])
        for eighth in range(8):
            track.add(triangle(root * (2 if eighth % 2 else 1), step * 0.9), b + eighth / 2, gain=0.3)
        for eighth, name in enumerate(tune[bar]):
            if name is None:
                continue
            length = 1
            while eighth + length < 8 and tune[bar][eighth + length] is None and length < 2:
                length += 1
            track.add(pulse(note(name), step * length * 0.92), b + eighth / 2, gain=0.16, pan=0.2)
        for beat in range(4):
            if beat in (0, 2):
                track.add(kick(), b + beat, gain=0.45)
            else:
                track.add(noise(0.14, 22, tilt=False), b + beat, gain=0.12)
        for sixteenth in range(0, 16, 2):
            track.add(noise(0.03, 120), b + sixteenth / 4, gain=0.04 if sixteenth % 4 else 0.06, pan=0.3)
    return track.finish(room=0.8, mix=0.12)


STYLES = {"guitar": guitar, "musicbox": musicbox, "jazz": jazz, "chiptune": chiptune}


def write(audio, out):
    pcm = (np.clip(audio.T, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "theme.wav"
        with wave.open(str(wav), "wb") as file:
            file.setnchannels(2)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes(pcm.tobytes())
        out.parent.mkdir(parents=True, exist_ok=True)
        # Apple Lossless in a CAF: small, and unlike AAC it has no encoder padding, so it loops seamlessly.
        subprocess.run(["afconvert", "-f", "caff", "-d", "alac", str(wav), str(out)], check=True)
    print(f"wrote {out} ({audio.shape[1] / RATE:.1f} s, {out.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--style", choices=STYLES, help="write one style to --out instead of the app's tracks")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    if args.style:
        write(STYLES[args.style](), args.out or Path(f"{args.style}.caf"))
    else:
        for name, style in APP_TRACKS.items():
            write(STYLES[style](), RESOURCES / f"{name}.caf")
