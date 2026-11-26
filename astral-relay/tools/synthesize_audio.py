#!/usr/bin/env python3
"""Render Astral Relay's original score and effects with NumPy and ffmpeg."""

from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np


SAMPLE_RATE = 44100
BPM = 174
BEAT = 60 / BPM
STEP = BEAT / 4
BARS = 32
TAU = 2 * np.pi
DESTINATION = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = np.random.default_rng(6229)


def seconds(duration):
    return np.arange(round(duration * SAMPLE_RATE)) / SAMPLE_RATE


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def sine(frequency, time, phase=0.0):
    return np.sin(TAU * frequency * time + phase)


def envelope(time, attack, decay):
    return np.minimum(time / attack, 1) * np.exp(-time / decay)


def taper(time, release):
    return np.clip((time[-1] - time) / release, 0, 1)


def noise(time):
    return RNG.uniform(-1, 1, time.size)


def high_noise(time):
    raw = noise(time)
    return np.diff(raw, prepend=raw[0]) * 0.6


def mix(target, signal, at, level=1.0, pan=0.0):
    """Add a mono voice, keeping its tail across the loop point."""
    start = round(at * SAMPLE_RATE) % target.shape[0]
    stereo = signal[:, None] * (level * np.sqrt([1 - pan, 1 + pan]))
    before_wrap = min(len(stereo), len(target) - start)
    target[start:start + before_wrap] += stereo[:before_wrap]
    target[:len(stereo) - before_wrap] += stereo[before_wrap:]


def kick():
    time = seconds(0.28)
    phase = TAU * (45 * time + 4.1 * (1 - np.exp(-time / 0.024)))
    core = np.tanh(1.55 * np.sin(phase)) * envelope(time, 0.0012, 0.067)
    snap = high_noise(time) * envelope(time, 0.0009, 0.01)
    return (core + 0.16 * snap) * taper(time, 0.026)


def snare(fill=False):
    time = seconds(0.24 if not fill else 0.14)
    body = sine(172, time) + 0.46 * sine(267, time)
    air = 0.54 * noise(time) + 0.75 * high_noise(time)
    clap = sum(envelope(np.maximum(time - offset, 0), 0.0007, 0.012)
               for offset in (0.0, 0.008, 0.017))
    return taper(time, 0.038) * (
        body * envelope(time, 0.0012, 0.052) * 0.42
        + air * (0.60 * envelope(time, 0.003, 0.060) + 0.21 * clap)
    )


def hat(open_hat=False):
    time = seconds(0.20 if open_hat else 0.074)
    metal = sum(sine(frequency, time) for frequency in (3398, 4513, 6797, 8437))
    return (0.76 * high_noise(time) + 0.060 * metal) * envelope(
        time, 0.0009, 0.068 if open_hat else 0.022
    ) * taper(time, 0.025)


def bass(note, duration, bright):
    time = seconds(duration)
    pitch = hz(note)
    phase = TAU * pitch * time
    drift = sine(4.2, time) * (0.11 if bright else 0.055)
    cutoff = 0.48 + 0.40 * np.exp(-time / 0.085)
    buzz = sum(np.sin(phase * harmonic + drift) * cutoff ** (harmonic - 1) / harmonic
              for harmonic in range(1, 9))
    signal = 0.60 * np.sin(phase) + 0.13 * np.sin(phase * 2) + 0.43 * np.tanh(1.4 * buzz)
    return signal * envelope(time, 0.008, 0.48) * taper(time, 0.034)


def pluck(note, duration, mellow=False):
    time = seconds(duration)
    pitch = hz(note)
    modulator = sine(pitch * 2, time) * (0.42 * np.exp(-time / 0.10))
    core = np.sin(TAU * pitch * time + modulator)
    harmonics = 0.34 * sine(pitch * 2.006, time) + 0.09 * sine(pitch * 3, time)
    decay = 0.15 if mellow else 0.085
    return (core + harmonics) * envelope(time, 0.009, decay) * taper(time, 0.035)


def pad(note, duration, detune):
    time = seconds(duration)
    pitch = hz(note) * detune
    drift = sine(0.7, time) * 0.13
    core = np.sin(TAU * pitch * time + drift) + 0.35 * sine(pitch * 2.005, time)
    upper = 0.16 * sine(pitch * 3, time) + 0.08 * sine(pitch * 4.009, time)
    return (core + upper) * envelope(time, 0.25, 2.8) * taper(time, 0.37)


def lead(note, duration):
    time = seconds(duration)
    pitch = hz(note)
    drift = sine(5.4, time) * np.minimum(time * 3.1, 0.48)
    phase = TAU * pitch * time + drift
    voice = np.sin(phase) + 0.33 * sine(pitch * 1.004, time)
    voice += (0.30 * np.sin(phase * 2) + 0.19 * np.sin(phase * 3)) * np.exp(-time / 0.36)
    return voice * envelope(time, 0.027, 0.60) * taper(time, 0.065)


def duck(bass_track, kicks):
    time = seconds(0.17)
    recovery = 1 - 0.50 * np.exp(-time / 0.049)
    for start in kicks:
        indices = (round(start * SAMPLE_RATE) + np.arange(len(time))) % len(bass_track)
        bass_track[indices] *= recovery[:, None]


def score():
    frames = round(BARS * 4 * BEAT * SAMPLE_RATE)
    drums = np.zeros((frames, 2), dtype=np.float32)
    bass_track = np.zeros_like(drums)
    harmony = np.zeros_like(drums)
    kick_sound, snare_sound, fill_sound = kick(), snare(), snare(fill=True)
    closed_hat, open_hat = hat(), hat(open_hat=True)
    kick_times = []
    chords = ((54, 57, 61, 64), (50, 54, 57, 61), (52, 57, 61, 64), (52, 56, 59, 64))
    bass_notes = (30, 26, 33, 28)
    leads = ((73, 76, 78), (76, 73, 69), (73, 76, 81), (80, 76, 71))
    kick_patterns = ((0, 6, 10), (0, 5, 10, 14), (0, 6, 10), (0, 7, 10, 15))
    bass_patterns = (
        ((0, 3.0, 0), (3.5, 1.9, 0), (6, 2.8, 12), (9, 2.6, 0), (13, 2.2, 7)),
        ((0, 3.7, 0), (4.5, 2.2, 0), (8, 1.7, 12), (10, 3.1, 0), (14, 1.6, 12)),
    )

    for bar in range(BARS):
        chord_index = bar % len(chords)
        start = bar * 4 * BEAT
        bridge = 16 <= bar < 20
        full = 4 <= bar < 16 or 20 <= bar

        kicks = (0, 9) if bridge else kick_patterns[bar % len(kick_patterns)]
        for step in kicks:
            at = start + step * STEP
            mix(drums, kick_sound, at, 0.54 if step == 0 else 0.43)
            kick_times.append(at)

        for step in (4, 12):
            mix(drums, snare_sound, start + step * STEP, 0.43 if step == 4 else 0.48)
        mix(drums, fill_sound, start + (11.30 if bar % 2 else 3.52) * STEP, 0.14, -0.18)
        if bar % 4 == 3 and not bridge:
            for step, level in ((13.5, 0.13), (14.4, 0.22), (15.25, 0.30)):
                mix(drums, fill_sound, start + step * STEP, level, 0.28)

        hat_steps = (2, 6, 10, 14) if bridge else (0, 2, 3, 5, 6, 8, 10, 11, 13, 14, 15)
        for step in hat_steps:
            accent = step in (2, 6, 10, 14)
            pan = 0.32 if step % 3 else -0.35
            voice = open_hat if accent else closed_hat
            mix(drums, voice, start + (step + (step % 2) * 0.14) * STEP,
                0.17 if accent else 0.09, pan)

        notes = ((0, 7.4, 0), (8, 6.8, 12)) if bridge else bass_patterns[bar % 2]
        for step, length, offset in notes:
            voice = bass(bass_notes[chord_index] + offset, STEP * length, full)
            mix(bass_track, voice, start + step * STEP, 0.28 if bridge else 0.35)

        chord = chords[chord_index]
        for index, note in enumerate(chord):
            spread = 0.34 + 0.10 * (index % 2)
            mix(harmony, pad(note, 4.9 * BEAT, 0.9973), start, 0.031, -spread)
            mix(harmony, pad(note, 4.9 * BEAT, 1.0023), start, 0.031, spread)

        arpeggio = (0, 2, 1, 3, 2, 1, 3, 2, 0, 2, 3, 1, 2, 3, 1, 2)
        for step, note_index in enumerate(arpeggio):
            if (full and step % 4 == 3) or (not full and step % 2):
                continue
            at = start + (step + 0.10) * STEP
            note = chord[note_index] + (24 if bridge and step in (4, 12) else 12)
            voice = pluck(note, 0.24, bridge)
            pan = 0.42 if step % 2 else -0.40
            mix(harmony, voice, at, 0.085 if step % 4 == 0 else 0.055, pan)
            mix(harmony, voice, at + 3 * STEP, 0.025, -pan)

        if bar >= 8 and not bridge:
            phrase = ((0.5, 3.8, 0), (6, 3.0, 1), (10.5, 4.5, 2))
            if bar % 2:
                phrase = ((0, 5.0, 0), (7.5, 2.0, 1), (12, 3.5, 2))
            for step, length, index in phrase:
                at = start + step * STEP
                voice = lead(leads[chord_index][index], length * STEP)
                mix(harmony, voice, at, 0.098, -0.10)
                mix(harmony, voice, at + 3 * STEP, 0.037, 0.64)
                mix(harmony, voice, at + 6 * STEP, 0.023, -0.61)

    duck(bass_track, kick_times)
    return np.tanh(0.86 * (drums + bass_track + harmony)) * 1.09


def laser():
    time = seconds(0.135)
    phase = TAU * (280 * time + 24 * (1 - np.exp(-time / 0.026)))
    beam = np.sin(phase) + 0.40 * np.sin(1.48 * phase) + 0.14 * high_noise(time)
    return beam * envelope(time, 0.002, 0.032) * taper(time, 0.025) * 0.58


def impact():
    time = seconds(0.22)
    phase = TAU * (65 * time + 8.6 * (1 - np.exp(-time / 0.032)))
    pulse = np.sin(phase) + 0.41 * np.sin(2.18 * phase)
    scrape = 0.53 * high_noise(time) * np.exp(-time / 0.031)
    return (pulse + scrape) * envelope(time, 0.002, 0.058) * taper(time, 0.04) * 0.57


def chime(notes, spacing, duration, tone_length):
    signal = np.zeros(round(duration * SAMPLE_RATE))
    for index, note in enumerate(notes):
        start = round(index * spacing * SAMPLE_RATE)
        time = seconds(min(tone_length, duration - index * spacing))
        pitch = hz(note)
        bell = sine(pitch, time) + 0.30 * sine(pitch * 2.006, time) + 0.12 * sine(pitch * 3.98, time)
        voice = bell * envelope(time, 0.004, 0.092) * taper(time, 0.033)
        signal[start:start + min(len(voice), len(signal) - start)] += voice[:len(signal) - start]
    return signal


def pickup():
    return chime((76, 81, 85), 0.042, 0.30, 0.14) * 0.52


def boost():
    time = seconds(0.57)
    phrase = chime((61, 66, 69, 73, 78), 0.055, 0.57, 0.18)
    phase = TAU * (46 * time + 440 * time ** 2)
    acceleration = envelope(time, 0.12, 0.26) * taper(time, 0.13)
    rocket = (0.72 * np.sin(phase) + 0.42 * high_noise(time)) * acceleration
    return np.tanh(0.54 * phrase + 0.45 * rocket)


def crash():
    time = seconds(0.72)
    phase = TAU * (32 * time + 12 * (1 - np.exp(-time / 0.055)))
    body = np.tanh(2 * np.sin(phase)) * envelope(time, 0.004, 0.16)
    debris = (0.52 * noise(time) + 0.54 * high_noise(time)) * envelope(time, 0.002, 0.085)
    return (body * 0.63 + debris * 0.34) * taper(time, 0.15)


def wav(path, signal):
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(1 if signal.ndim == 1 else signal.shape[1])
        writer.setsampwidth(2)
        writer.setframerate(SAMPLE_RATE)
        writer.writeframes((np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes())


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        intermediate = Path(folder) / "score.wav"
        wav(intermediate, score())
        subprocess.run([
            "ffmpeg", "-loglevel", "error", "-y", "-i", str(intermediate),
            "-c:a", "libvorbis", "-q:a", "5", "-metadata", "title=Redshift Relay",
            str(DESTINATION / "redshift_relay.ogg"),
        ], check=True)
    for name, effect in (("fire", laser), ("hit", impact), ("pickup", pickup),
                         ("boost", boost), ("crash", crash)):
        wav(DESTINATION / f"{name}.wav", effect())


if __name__ == "__main__":
    main()
