# phinstrument Code Guide (Beginner-Friendly)

This guide explains how the app works at a conceptual level. It focuses on the main data flow from device motion to audio generation and how the SwiftUI UI presents and controls that behavior.

## 1) App entry point and lifecycle

- The app starts in `phinstrument/phinstrumentApp.swift`.
- The `App` entry point creates a `WindowGroup` and loads `ContentView` as the root screen.
- There is no separate model layer file; most behavior lives in `phinstrument/ContentView.swift`.

## 2) File map and responsibilities

The app is essentially one large file plus a small entry point:

- `phinstrument/phinstrumentApp.swift`: app entry point.
- `phinstrument/ContentView.swift`: all core logic and UI, including:
  - Theme definitions and constants
  - Audio synthesis engine and recording
  - Motion sensor handling
  - UI components and layout
  - Settings screen
- `phinstrumentTests/phinstrumentTests.swift`: empty test scaffold.

## 3) Core concepts by section (ContentView.swift)

### Themes and constants

- `AppTheme` defines named themes and their colors.
- `AudioConstants` defines absolute bounds for frequency and rate as well as sample rate.
- Purpose: keep UI color choices and audio bounds consistent across the app.

### Key quantization

- `RootNote`, `ScaleType`, and `KeyQuantizer` implement musical key snapping.
- The quantizer converts frequency → MIDI note, finds a nearest note in the selected scale, then returns a snapped frequency.
- Purpose: when key quantization is enabled, roll-based pitch changes feel musical.

### Reusable UI components

- `LevelIndicator`: draws a circle target and a bubble that moves based on pitch and roll.
- `RangeSlider`: two-thumb slider for min/max ranges (used for freq and rate).
- `OscilloscopeView`: draws a waveform from the most recent audio samples.

### Audio system

- `AudioManager` is the heart of sound generation and recording.
- It uses `AVAudioEngine` and a custom `AVAudioSourceNode` render callback to synthesize samples.
- Responsibilities:
  - Track current pitch, envelope state, and waveform mix.
  - Generate waveform samples (sine/triangle/saw/square morph).
  - Apply ADSR envelope, unison detune, optional chord, and low-pass filter.
  - Schedule “plucks” using a timer for rhythmic beeps.
  - Record audio by installing a tap on the mixer and writing to a file.

### Motion system

- `MotionManager` wraps `CMMotionManager` and produces normalized pitch/roll values.
- It uses direct callbacks (closures) so audio updates can bypass SwiftUI redraw timing.
- Purpose: map device tilt to audio pitch (roll) and rate (pitch).

### Rhythm helpers

- `RhythmHelper` converts between time rates and musical subdivisions for tempo sync.

### Settings view

- `SettingsView` is a separate SwiftUI screen presented as a sheet.
- It allows changing the theme, BPM, and “hold to play” behavior.
- Uses a custom toolbar modifier for dark navigation styling.

## 4) Main UI walkthrough (ContentView)

`ContentView` is the main screen and wires state to the `AudioManager` and `MotionManager`.

### Top-level layout

- Background uses the current theme.
- A vertical stack contains the oscilloscope, main controls, module panels, and playback controls.
- A gear icon opens the settings sheet.

### Oscilloscope

- A timer polls the audio manager’s buffer and renders a live waveform.
- This is visual feedback of the actual synthesized audio.

### Rate / Level / Frequency row

- Left: rate display with a lock and optional tempo subdivision display.
- Center: level indicator showing current pitch/roll.
- Right: frequency display with lock and optional note-name display.

### Module panels

- **Decay module**: ADSR controls + legato toggle.
- **Waveform module**: waveform morph slider plus unison, detune, and filter.
- **KeyFX module**: key and scale selection, chord toggle, and tolerance.

### Range sliders

- Two range sliders define min/max for frequency and rate.
- These ranges reshape how tilt maps to sound.

### Playback and recording

- Play/Pause controls the pluck loop (or legato sustain).
- “Hold to play” can make play behave like a momentary button.
- Record creates an audio file from the main mixer output.

## 5) Data flow: how motion becomes sound and UI

Here is the conceptual pipeline:

1) **Motion input**  
   Device motion produces pitch and roll values.

2) **MotionManager normalization**  
   Values are clamped to stable ranges for control mapping.

3) **Direct callbacks to AudioManager**  
   - Roll updates pitch (frequency).
   - Pitch updates rate (pluck interval).
   - If locked or in legato mode, updates are ignored.

4) **Audio synthesis**  
   The audio engine render callback generates samples using the current parameters.

5) **Oscilloscope feedback**  
   A ring buffer of samples is exposed to the UI and drawn in the oscilloscope.

6) **UI reflects state**  
   SwiftUI displays current rate, frequency, and control settings.

## 6) How to trace a feature

When you want to understand or modify behavior:

- Start at `ContentView` to find the UI control that changes a value.
- Follow the `@State` or binding to where it updates `AudioManager`.
- Look for matching methods in `AudioManager` that apply the change.
- If motion is involved, check `MotionManager` and its callbacks in `ContentView`.
- For tempo or key behavior, check `RhythmHelper` or `KeyQuantizer`.

## 7) Testing status and opportunities

- `phinstrumentTests/phinstrumentTests.swift` is empty.
- Useful candidates for tests:
  - `KeyQuantizer` math (frequency ↔ note, snapping rules).
  - `RhythmHelper` conversions between rate and subdivision.
  - Pure mapping functions (roll → frequency, pitch → rate) if factored.

If you want, I can also produce a shorter “cheat sheet” or add diagrams (data flow or UI map) without changing any code.
