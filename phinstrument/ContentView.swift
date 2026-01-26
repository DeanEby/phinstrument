//
//  ContentView.swift
//  phinstrument
//
//  Created by Dean Eby on 1/8/26.
//


import SwiftUI
import AVFoundation
import CoreMotion
import Combine

// MARK: - Color Themes
enum AppTheme: String, CaseIterable {
    case midnight = "Midnight"      // Current dark theme
    case y2k = "Y2K"               // Early 2000s futuristic
    case terminal = "Terminal"      // Hacker/Matrix green
    
    var background: Color {
        switch self {
        case .midnight: return .black
        case .y2k: return Color(red: 0.05, green: 0.0, blue: 0.15)  // Deep purple-black
        case .terminal: return Color(red: 0.0, green: 0.05, blue: 0.0)  // Near-black green
        }
    }
    
    var decay: Color {
        switch self {
        case .midnight: return .orange
        case .y2k: return Color(red: 1.0, green: 0.4, blue: 0.8)  // Hot pink
        case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.4)  // Bright green
        }
    }
    
    var waveform: Color {
        switch self {
        case .midnight: return .cyan
        case .y2k: return Color(red: 0.4, green: 0.8, blue: 1.0)  // Electric blue
        case .terminal: return Color(red: 0.0, green: 0.8, blue: 0.3)  // Matrix green
        }
    }
    
    var keyFX: Color {
        switch self {
        case .midnight: return .pink
        case .y2k: return Color(red: 0.8, green: 1.0, blue: 0.2)  // Lime green
        case .terminal: return Color(red: 0.2, green: 1.0, blue: 0.6)  // Cyan-green
        }
    }
    
    var freqRange: Color {
        switch self {
        case .midnight: return .green
        case .y2k: return Color(red: 0.0, green: 1.0, blue: 0.8)  // Turquoise
        case .terminal: return Color(red: 0.0, green: 0.7, blue: 0.0)  // Dark green
        }
    }
    
    var rateRange: Color {
        switch self {
        case .midnight: return .purple
        case .y2k: return Color(red: 0.8, green: 0.4, blue: 1.0)  // Bright purple
        case .terminal: return Color(red: 0.3, green: 0.9, blue: 0.3)  // Light green
        }
    }
    
    var accent: Color {
        switch self {
        case .midnight: return .blue
        case .y2k: return Color(red: 1.0, green: 0.2, blue: 0.6)  // Magenta
        case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.0)  // Pure green
        }
    }
    
    var textPrimary: Color {
        switch self {
        case .midnight: return .white
        case .y2k: return .white
        case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.4)  // Green text
        }
    }
    
    var textSecondary: Color {
        switch self {
        case .midnight: return .gray
        case .y2k: return Color(red: 0.7, green: 0.7, blue: 0.9)  // Light lavender
        case .terminal: return Color(red: 0.0, green: 0.6, blue: 0.2)  // Dim green
        }
    }
    
    var oscilloscope: Color {
        switch self {
        case .midnight: return .white
        case .y2k: return Color(red: 0.4, green: 1.0, blue: 1.0)  // Bright cyan
        case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.0)  // Pure green
        }
    }
    
    var levelIndicatorSafe: Color {
        switch self {
        case .midnight: return .green
        case .y2k: return Color(red: 0.4, green: 1.0, blue: 0.8)  // Aqua
        case .terminal: return Color(red: 0.0, green: 0.8, blue: 0.0)
        }
    }
    
    var levelIndicatorWarn: Color {
        switch self {
        case .midnight: return .yellow
        case .y2k: return Color(red: 1.0, green: 0.8, blue: 0.0)  // Gold
        case .terminal: return Color(red: 0.5, green: 1.0, blue: 0.0)  // Yellow-green
        }
    }
    
    var levelIndicatorHot: Color {
        switch self {
        case .midnight: return .orange
        case .y2k: return Color(red: 1.0, green: 0.2, blue: 0.4)  // Hot red-pink
        case .terminal: return Color(red: 1.0, green: 0.5, blue: 0.0)  // Orange (warning)
        }
    }
}

// MARK: - Audio Constants
struct AudioConstants {
    // Absolute limits for sliders
    static let absoluteMinFreq: Double = 20.0       // 20 Hz
    static let absoluteMaxFreq: Double = 20000.0    // 20 kHz
    static let absoluteMinRate: Double = 0.01   // 10ms
    static let absoluteMaxRate: Double = 3.0    // 3 seconds
    static let sampleRate: Double = 44100.0
}

// MARK: - Key Quantization
enum RootNote: Int, CaseIterable {
    case c = 0, cSharp = 1, d = 2, dSharp = 3, e = 4, f = 5
    case fSharp = 6, g = 7, gSharp = 8, a = 9, aSharp = 10, b = 11
    
    var name: String {
        switch self {
        case .c: return "C"
        case .cSharp: return "C#"
        case .d: return "D"
        case .dSharp: return "D#"
        case .e: return "E"
        case .f: return "F"
        case .fSharp: return "F#"
        case .g: return "G"
        case .gSharp: return "G#"
        case .a: return "A"
        case .aSharp: return "A#"
        case .b: return "B"
        }
    }
}

enum ScaleType: String, CaseIterable {
    case off = "Off"
    case major = "Maj"
    case minor = "Min"
}

struct KeyQuantizer {
    // Semitone intervals for scales (relative to root)
    static let majorIntervals: Set<Int> = [0, 2, 4, 5, 7, 9, 11]  // W W H W W W H
    static let minorIntervals: Set<Int> = [0, 2, 3, 5, 7, 8, 10]  // W H W W H W W
    
    // Note names for display
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    /// Convert frequency to MIDI note number (can be fractional)
    static func frequencyToMidiNote(_ freq: Double) -> Double {
        return 69.0 + 12.0 * log2(freq / 440.0)
    }
    
    /// Convert MIDI note number to frequency
    static func midiNoteToFrequency(_ note: Double) -> Double {
        return 440.0 * pow(2.0, (note - 69.0) / 12.0)
    }
    
    /// Convert frequency to note name with octave (e.g., "A4", "C#3")
    static func frequencyToNoteName(_ freq: Double) -> String {
        let midiNote = Int(round(frequencyToMidiNote(freq)))
        let noteIndex = ((midiNote % 12) + 12) % 12
        let octave = (midiNote / 12) - 1
        return "\(noteNames[noteIndex])\(octave)"
    }
    
    /// Get semitone offset from root note (0-11)
    static func getSemitoneFromRoot(_ midiNote: Int, root: RootNote) -> Int {
        var semitone = (midiNote - root.rawValue) % 12
        if semitone < 0 { semitone += 12 }
        return semitone
    }
    
    /// Get semitone offset from C (0-11)
    static func getSemitoneFromC(_ midiNote: Int) -> Int {
        var semitone = midiNote % 12
        if semitone < 0 { semitone += 12 }
        return semitone
    }
    
    /// Quantize frequency to nearest note in the given key with configurable tolerance
    /// - Parameters:
    ///   - frequency: The input frequency to quantize
    ///   - root: The root note of the key
    ///   - scale: The scale type (major/minor/off)
    ///   - toleranceCents: How many cents off the note you can be before snapping (0-50)
    static func quantize(_ frequency: Double, root: RootNote, scale: ScaleType, toleranceCents: Double = 25.0) -> Double {
        guard scale != .off else { return frequency }
        
        let intervals: Set<Int> = scale == .major ? majorIntervals : minorIntervals
        let toleranceSemitones = toleranceCents / 100.0
        
        let midiNote = frequencyToMidiNote(frequency)
        let baseMidiNote = Int(round(midiNote))
        
        // Search for nearest valid note (up to 6 semitones in each direction)
        var bestNote = baseMidiNote
        var smallestDistance = Double.infinity
        
        for offset in -6...6 {
            let candidateNote = baseMidiNote + offset
            let semitoneFromRoot = getSemitoneFromRoot(candidateNote, root: root)
            
            if intervals.contains(semitoneFromRoot) {
                let distance = abs(Double(candidateNote) - midiNote)
                if distance < smallestDistance {
                    smallestDistance = distance
                    bestNote = candidateNote
                }
            }
        }
        
        // Calculate detune: how far the original was from the quantized note
        let detune = midiNote - Double(bestNote)
        
        // Clamp detune to tolerance range
        let clampedDetune = max(-toleranceSemitones, min(toleranceSemitones, detune))
        
        // Return the quantized note with the clamped detune applied
        return midiNoteToFrequency(Double(bestNote) + clampedDetune)
    }
}

// MARK: - Level Indicator
struct LevelIndicator: View {
    var pitch: Double  // -1 to 1
    var roll: Double   // -0.5 to 0.5
    var size: CGFloat = 80
    var theme: AppTheme = .midnight
    
    var body: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(theme.textSecondary.opacity(0.4), lineWidth: 2)
                .frame(width: size, height: size)
            
            // Crosshairs
            Path { path in
                path.move(to: CGPoint(x: size/2, y: 4))
                path.addLine(to: CGPoint(x: size/2, y: size - 4))
                path.move(to: CGPoint(x: 4, y: size/2))
                path.addLine(to: CGPoint(x: size - 4, y: size/2))
            }
            .stroke(theme.textSecondary.opacity(0.3), lineWidth: 1)
            .frame(width: size, height: size)
            
            // Center target circle
            Circle()
                .stroke(theme.textSecondary.opacity(0.3), lineWidth: 1)
                .frame(width: size * 0.4, height: size * 0.4)
            
            // Bubble/dot indicator
            Circle()
                .fill(bubbleColor)
                .frame(width: 14, height: 14)
                .shadow(color: bubbleColor.opacity(0.5), radius: 4)
                .offset(x: bubbleOffsetX, y: bubbleOffsetY)
        }
        .frame(width: size, height: size)
    }
    
    // Map roll (-0.5 to 0.5) to X position
    private var bubbleOffsetX: CGFloat {
        let maxOffset = (size / 2) - 10
        return CGFloat(roll * 2) * maxOffset  // roll * 2 to normalize to -1...1
    }
    
    // Map pitch (-1 to 1) to Y position (forward = down)
    private var bubbleOffsetY: CGFloat {
        let maxOffset = (size / 2) - 10
        return CGFloat(pitch) * maxOffset
    }
    
    // Color changes based on distance from center
    private var bubbleColor: Color {
        let distance = sqrt(pow(roll * 2, 2) + pow(pitch, 2))
        if distance < 0.2 {
            return theme.levelIndicatorSafe
        } else if distance < 0.6 {
            return theme.levelIndicatorWarn
        } else {
            return theme.levelIndicatorHot
        }
    }
}

// MARK: - Range Slider
struct RangeSlider: View {
    @Binding var lowValue: Double
    @Binding var highValue: Double
    let range: ClosedRange<Double>
    let useLogScale: Bool
    var tint: Color = .blue
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let lowPosition = valueToPosition(lowValue, in: width)
            let highPosition = valueToPosition(highValue, in: width)
            
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                // Selected range
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint)
                    .frame(width: highPosition - lowPosition, height: 4)
                    .offset(x: lowPosition)
                
                // Low thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .offset(x: lowPosition - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = max(0, min(value.location.x, highPosition - 16))
                                lowValue = positionToValue(newPos, in: width)
                            }
                    )
                
                // High thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .offset(x: highPosition - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = max(lowPosition + 16, min(value.location.x, width))
                                highValue = positionToValue(newPos, in: width)
                            }
                    )
            }
        }
        .frame(height: 24)
    }
    
    private func valueToPosition(_ value: Double, in width: CGFloat) -> CGFloat {
        if useLogScale {
            let logMin = log(range.lowerBound)
            let logMax = log(range.upperBound)
            let logValue = log(value)
            return CGFloat((logValue - logMin) / (logMax - logMin)) * width
        } else {
            return CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * width
        }
    }
    
    private func positionToValue(_ position: CGFloat, in width: CGFloat) -> Double {
        let ratio = Double(position / width)
        if useLogScale {
            let logMin = log(range.lowerBound)
            let logMax = log(range.upperBound)
            return exp(logMin + ratio * (logMax - logMin))
        } else {
            return range.lowerBound + ratio * (range.upperBound - range.lowerBound)
        }
    }
}

// MARK: - Oscilloscope View
struct OscilloscopeView: View {
    let samples: [Float]
    var height: CGFloat = 80
    var lineColor: Color = .white
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let midY = height / 2
            
            ZStack {
                // Grid lines
                Path { path in
                    // Horizontal center line
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: width, y: midY))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                
                // Waveform
                if samples.count > 1 {
                    Path { path in
                        let step = width / CGFloat(samples.count - 1)
                        
                        for (index, sample) in samples.enumerated() {
                            let x = CGFloat(index) * step
                            let y = midY - CGFloat(sample) * (midY - 4)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(lineColor, lineWidth: 1.5)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Audio Manager
class AudioManager: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var sourceNode: AVAudioSourceNode?
    
    // Oscilloscope buffer
    private let oscilloscopeBufferSize = 256
    private var _oscilloscopeBuffer: [Float] = []
    private var oscilloscopeWriteIndex = 0
    var oscilloscopeSamples: [Float] {
        // Return a copy of the current buffer for display
        let buffer = _oscilloscopeBuffer
        guard buffer.count == oscilloscopeBufferSize else { return Array(repeating: 0, count: oscilloscopeBufferSize) }
        // Reorder so it starts from the write position for continuous display
        let start = oscilloscopeWriteIndex
        return Array(buffer[start...]) + Array(buffer[..<start])
    }
    
    // Thread-safe state using atomic-like pattern
    private var _currentFrequency: Double = 220.0  // A3 - middle of range, easily audible
    private var _samplesSinceNoteOn: Int = Int.max  // Start silent
    private var _samplesSinceNoteOff: Int = Int.max // Track release phase
    private var _noteIsOn: Bool = false             // Gate state
    private var _envelopeLevel: Double = 0.0        // Current envelope level (for release)
    
    private var beepTimer: Timer?
    private var currentRate: Double = 0.5
    
    // User-adjustable parameters
    var waveformMix: Double = 0.17     // 0=sine, 0.33=triangle, 0.66=saw, 1=square
    var frequencyLocked: Bool = false
    var rateLocked: Bool = false
    var selectedRoot: RootNote = .c    // Root note of key
    var selectedScale: ScaleType = .off // Scale type (off/major/minor)
    var chordMode: Bool = false        // Play chord (root + third + octave)
    var unisonCount: Int = 1           // Number of unison voices (1, 2, 3, or 5)
    var detuneAmount: Double = 0.0     // Detune in cents (0-50)
    var filterCutoff: Double = 1.0     // Low-pass filter cutoff (0=dark, 1=bright/bypassed)
    var keyTolerance: Double = 25.0    // Cents tolerance before snapping to next note (0-50)
    var rateSyncedToTempo: Bool = false // When true, rate snaps to subdivisions
    var bpm: Double = 120.0            // BPM for tempo sync
    
    // ADSR envelope parameters (all in seconds, sustain is 0-1 level)
    var attackTime: Double = 0.01      // Attack time (0.001 to 1.0)
    var decayTime: Double = 0.1        // Decay time (0.01 to 1.0)
    var sustainLevel: Double = 0.7     // Sustain level (0 to 1)
    var releaseTime: Double = 0.2      // Release time (0.01 to 2.0)
    
    // Legato mode
    var legatoMode: Bool = false       // When true, plays constant note (no retriggering)
    
    // Custom ranges
    var minFrequency: Double = 50.0     // Low end of frequency range
    var maxFrequency: Double = 1000.0   // High end of frequency range
    var minRate: Double = 0.01      // Fast end of rate range (10ms)
    var maxRate: Double = 0.5       // Slow end of rate range (500ms)
    
    // Chord frequency (calculated from root)
    private var _tenthFrequency: Double = 0.0  // 10th interval (octave + 3rd)
    
    var currentFrequency: Double {
        get { _currentFrequency }
        set { _currentFrequency = newValue }
    }
    
    /// Calculate chord frequencies based on root and key (diatonic 10ths)
    func updateChordFrequencies() {
        // Determine the scale degree of the current note relative to the key root
        let midiNote = KeyQuantizer.frequencyToMidiNote(_currentFrequency)
        let semitoneFromRoot = KeyQuantizer.getSemitoneFromRoot(Int(round(midiNote)), root: selectedRoot)
        
        // Diatonic 10ths: use major 10th (+16) or minor 10th (+15) based on scale degree
        // This keeps the harmony note within the key
        
        let tenthSemitones: Double
        
        if selectedScale == .major {
            // Major scale: I, IV, V get major 10th; ii, iii, vi, vii° get minor 10th
            // Scale degrees with major 10th: 0 (I), 5 (IV), 7 (V)
            let majorTenthDegrees: Set<Int> = [0, 5, 7]
            tenthSemitones = majorTenthDegrees.contains(semitoneFromRoot) ? 16.0 : 15.0
        } else {
            // Minor scale: III, VI, VII get major 10th; i, ii°, iv, v get minor 10th
            // Scale degrees with major 10th: 3 (III), 8 (VI), 10 (VII)
            let majorTenthDegrees: Set<Int> = [3, 8, 10]
            tenthSemitones = majorTenthDegrees.contains(semitoneFromRoot) ? 16.0 : 15.0
        }
        
        _tenthFrequency = _currentFrequency * pow(2.0, tenthSemitones / 12.0)
    }
    
    /// Generate waveform sample based on phase and waveformMix
    /// Smoothly morphs between sine → triangle → saw → square
    private func generateWaveform(phase: Double) -> Double {
        let normalizedPhase = phase / (2.0 * Double.pi)  // 0 to 1
        
        // Individual waveforms
        let sine = sin(phase)
        let triangle = 4.0 * abs(normalizedPhase - 0.5) - 1.0
        let saw = 2.0 * normalizedPhase - 1.0
        let square: Double = normalizedPhase < 0.5 ? 1.0 : -1.0
        
        // Morph between waveforms based on waveformMix (0 to 1)
        let mix = waveformMix
        
        if mix <= 0.333 {
            // Sine to Triangle
            let t = mix / 0.333
            return sine * (1 - t) + triangle * t
        } else if mix <= 0.666 {
            // Triangle to Saw
            let t = (mix - 0.333) / 0.333
            return triangle * (1 - t) + saw * t
        } else {
            // Saw to Square
            let t = (mix - 0.666) / 0.334
            return saw * (1 - t) + square * t
        }
    }
    
    init() {
        audioEngine = AVAudioEngine()
        _oscilloscopeBuffer = Array(repeating: 0, count: oscilloscopeBufferSize)
        
        setupAudioSession()
        setupAudioEngine()
        startEngine()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio session setup failed
        }
    }
    
    private func setupAudioEngine() {
        let sampleRate = AudioConstants.sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        // Capture self values for the render block
        var phaseRoot: Double = 0.0
        var phaseTenth: Double = 0.0
        // Unison phases (max 5 voices)
        var unisonPhases: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
        // Low-pass filter state
        var filterState: Double = 0.0
        // Anti-click: smoothed envelope follower
        var smoothedEnvelope: Double = 0.0
        // Minimum anti-click time in samples (~3ms)
        let antiClickSamples = Int(0.003 * sampleRate)
        
        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first,
                  let bufferPointer = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            
            let rootFreq = self._currentFrequency
            let tenthFreq = self._tenthFrequency
            let isChordMode = self.chordMode && self.selectedScale != .off
            let unisonVoices = self.unisonCount
            let detuneCents = self.detuneAmount
            let isLegato = self.legatoMode
            
            let phaseIncrementRoot = 2.0 * Double.pi * rootFreq / sampleRate
            let phaseIncrementTenth = 2.0 * Double.pi * tenthFreq / sampleRate
            
            // ADSR parameters in samples (with minimum anti-click times)
            let attackSamples = max(antiClickSamples, Int(self.attackTime * sampleRate))
            let decaySamples = max(antiClickSamples, Int(self.decayTime * sampleRate))
            let sustainLevel = self.sustainLevel
            let releaseSamples = max(antiClickSamples, Int(self.releaseTime * sampleRate))
            
            // Calculate detuned frequencies for unison voices
            // Spread detune symmetrically: -detune, 0, +detune, etc.
            var unisonIncrements: [Double] = []
            if unisonVoices > 1 {
                for i in 0..<unisonVoices {
                    // Spread from -detuneCents to +detuneCents
                    let spread = Double(i) / Double(unisonVoices - 1) * 2.0 - 1.0  // -1 to +1
                    let detuneRatio = pow(2.0, (spread * detuneCents) / 1200.0)  // Convert cents to ratio
                    let freq = rootFreq * detuneRatio
                    unisonIncrements.append(2.0 * Double.pi * freq / sampleRate)
                }
            }
            
            for frame in 0..<Int(frameCount) {
                var sample: Float = 0.0
                var envelope: Double = 0.0
                
                let noteOn = self._noteIsOn
                let samplesSinceOn = self._samplesSinceNoteOn
                let samplesSinceOff = self._samplesSinceNoteOff
                
                if isLegato && noteOn {
                    // Legato mode: sustained note with ADSR
                    if samplesSinceOn < attackSamples {
                        // Attack phase: linear ramp from 0 to 1
                        envelope = Double(samplesSinceOn) / Double(max(1, attackSamples))
                    } else if samplesSinceOn < attackSamples + decaySamples {
                        // Decay phase: exponential decay from 1 to sustain level
                        let decayIndex = samplesSinceOn - attackSamples
                        let progress = Double(decayIndex) / Double(max(1, decaySamples))
                        envelope = 1.0 - (1.0 - sustainLevel) * progress
                    } else {
                        // Sustain phase: hold at sustain level
                        envelope = sustainLevel
                    }
                    self._envelopeLevel = envelope
                    self._samplesSinceNoteOn += 1
                } else if noteOn {
                    // Normal pluck mode with ADSR
                    if samplesSinceOn < attackSamples {
                        // Attack phase
                        envelope = Double(samplesSinceOn) / Double(max(1, attackSamples))
                    } else if samplesSinceOn < attackSamples + decaySamples {
                        // Decay phase
                        let decayIndex = samplesSinceOn - attackSamples
                        let progress = Double(decayIndex) / Double(max(1, decaySamples))
                        envelope = 1.0 - (1.0 - sustainLevel) * progress
                    } else if samplesSinceOn < attackSamples + decaySamples + releaseSamples {
                        // Auto-release phase (for pluck mode)
                        let releaseIndex = samplesSinceOn - attackSamples - decaySamples
                        let progress = Double(releaseIndex) / Double(max(1, releaseSamples))
                        envelope = sustainLevel * (1.0 - progress)
                    } else {
                        // Note finished
                        envelope = 0.0
                        self._noteIsOn = false
                    }
                    self._envelopeLevel = envelope
                    self._samplesSinceNoteOn += 1
                } else if samplesSinceOff < releaseSamples {
                    // Release phase (when note turned off in legato mode)
                    let progress = Double(samplesSinceOff) / Double(max(1, releaseSamples))
                    envelope = self._envelopeLevel * (1.0 - progress)
                    self._samplesSinceNoteOff += 1
                }
                
                // Anti-click: smooth the envelope to prevent sudden jumps
                // This is a one-pole lowpass on the envelope itself
                let envelopeSmoothingCoeff = 0.005  // ~3ms smoothing at 44.1kHz
                smoothedEnvelope = smoothedEnvelope + envelopeSmoothingCoeff * (envelope - smoothedEnvelope)
                envelope = smoothedEnvelope
                
                // Generate sound if envelope is active
                if envelope > 0.001 {
                    // Generate waveform with unison
                    var rootWaveform: Double
                    if unisonVoices > 1 {
                        // Mix all unison voices
                        var unisonSum = 0.0
                        for i in 0..<unisonVoices {
                            unisonSum += self.generateWaveform(phase: unisonPhases[i])
                        }
                        rootWaveform = unisonSum / Double(unisonVoices)
                    } else {
                        rootWaveform = self.generateWaveform(phase: phaseRoot)
                    }
                    
                    var outputWaveform: Double
                    if isChordMode {
                        // Generate chord: root + 10th (mixed and normalized)
                        let tenthWaveform = self.generateWaveform(phase: phaseTenth)
                        outputWaveform = (rootWaveform + tenthWaveform * 0.7) / 1.7
                    } else {
                        outputWaveform = rootWaveform
                    }
                    
                    // Apply low-pass filter (one-pole filter)
                    // filterCutoff: 0 = very dark (20Hz), 1 = bright (bypassed)
                    let cutoff = self.filterCutoff
                    if cutoff < 0.99 {
                        // Map cutoff (0-1) to filter coefficient
                        // Lower cutoff = more filtering (darker sound)
                        let minFreq = 80.0   // Minimum cutoff frequency
                        let maxFreq = 15000.0 // Maximum cutoff frequency
                        let cutoffFreq = minFreq + (maxFreq - minFreq) * cutoff * cutoff  // Quadratic for better feel
                        let rc = 1.0 / (2.0 * Double.pi * cutoffFreq)
                        let dt = 1.0 / sampleRate
                        let alpha = dt / (rc + dt)
                        
                        filterState = filterState + alpha * (outputWaveform - filterState)
                        outputWaveform = filterState
                    }
                    
                    sample = Float(outputWaveform * envelope * 0.8)
                }
                
                bufferPointer[frame] = sample
                
                // Capture samples for oscilloscope (downsample by taking every Nth sample)
                if frame % 4 == 0 {
                    let bufferSize = self._oscilloscopeBuffer.count
                    if bufferSize > 0 {
                        self._oscilloscopeBuffer[self.oscilloscopeWriteIndex] = sample
                        self.oscilloscopeWriteIndex = (self.oscilloscopeWriteIndex + 1) % bufferSize
                    }
                }
                
                // Update phases
                phaseRoot += phaseIncrementRoot
                if phaseRoot >= 2.0 * Double.pi { phaseRoot -= 2.0 * Double.pi }
                
                phaseTenth += phaseIncrementTenth
                if phaseTenth >= 2.0 * Double.pi { phaseTenth -= 2.0 * Double.pi }
                
                // Update unison phases
                for i in 0..<unisonVoices {
                    if i < unisonIncrements.count {
                        unisonPhases[i] += unisonIncrements[i]
                        if unisonPhases[i] >= 2.0 * Double.pi { unisonPhases[i] -= 2.0 * Double.pi }
                    }
                }
            }
            
            return noErr
        }
        
        guard let sourceNode = sourceNode else { return }
        
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.mainMixerNode.outputVolume = 1.0
    }
    
    private func startEngine() {
        do {
            try audioEngine.start()
        } catch {
            // Audio engine failed to start
        }
    }
    
    /// Trigger a pluck sound (note on)
    func pluck() {
        _noteIsOn = true
        _samplesSinceNoteOn = 0
        _samplesSinceNoteOff = Int.max
    }
    
    /// Turn note off (for legato mode release)
    func noteOff() {
        if _noteIsOn {
            _noteIsOn = false
            _samplesSinceNoteOff = 0
        }
    }
    
    /// Start legato mode (continuous note)
    func startLegato() {
        stopBeeping()
        legatoMode = true
        pluck()  // Start the note
    }
    
    /// Stop legato mode
    func stopLegato() {
        legatoMode = false
        noteOff()
    }
    
    /// Update the frequency based on roll value (-0.5 to 0.5)
    /// Left (negative) = low pitch, Right (positive) = high pitch
    func updateFrequency(fromRoll roll: Double) {
        // Map roll (-0.5...0.5) to custom frequency range
        // Using logarithmic scaling for more musical feel
        let normalizedRoll = (roll + 0.5)  // Convert to 0...1
        
        // Logarithmic interpolation between min and max frequency
        let logMin = log(minFrequency)
        let logMax = log(maxFrequency)
        let logFreq = logMin + (logMax - logMin) * normalizedRoll
        
        var freq = exp(logFreq)
        
        // Apply key quantization if enabled (with configurable tolerance)
        freq = KeyQuantizer.quantize(freq, root: selectedRoot, scale: selectedScale, toleranceCents: keyTolerance)
        
        _currentFrequency = freq
        
        // Update chord frequencies if chord mode is active
        if chordMode {
            updateChordFrequencies()
        }
    }
    
    /// Update the beep rate based on pitch value (-1 to 1)
    /// Forward (positive) = fast, Backward (negative) = slow
    func updateRate(fromPitch pitch: Double) {
        // Map pitch to custom rate range
        // pitch 1 (forward) = minRate (fast), pitch -1 (back) = maxRate (slow)
        let normalizedPitch = (pitch + 1.0) / 2.0  // Convert to 0...1
        
        // Linear interpolation: 0 = maxRate (slow), 1 = minRate (fast)
        var rate = maxRate - (maxRate - minRate) * normalizedPitch
        
        // Clamp to valid range
        rate = max(minRate, min(maxRate, rate))
        
        // If synced to tempo, quantize to nearest subdivision
        if rateSyncedToTempo {
            let subdivision = RhythmHelper.rateToSubdivision(rate: rate, bpm: bpm)
            rate = RhythmHelper.subdivisionToRate(bpm: bpm, subdivision: subdivision)
            // Clamp quantized rate to valid range
            rate = max(minRate, min(maxRate, rate))
        }
        
        currentRate = rate
        
        // Don't restart timer here - just update the rate value
        // The timer will use the new value on its next schedule
    }
    
    private func scheduleNextPluck() {
        beepTimer?.invalidate()
        beepTimer = Timer.scheduledTimer(withTimeInterval: currentRate, repeats: false) { [weak self] _ in
            self?.pluck()
            self?.scheduleNextPluck()  // Schedule the next one with current rate
        }
        // Add timer to common run loop mode so it fires during scrolling
        if let timer = beepTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    func startBeeping() {
        pluck()  // Immediate first pluck
        scheduleNextPluck()
    }
    
    func stopBeeping() {
        beepTimer?.invalidate()
        beepTimer = nil
    }
    
    deinit {
        stopBeeping()
        audioEngine.stop()
    }
}

// MARK: - Motion Manager
class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0.0  // Forward/backward tilt (-1 to 1)
    @Published var roll: Double = 0.0   // Left/right tilt (-1 to 1)
    
    // Direct callbacks for real-time updates (bypasses SwiftUI)
    var onPitchUpdate: ((Double) -> Void)?
    var onRollUpdate: ((Double) -> Void)?
    
    init() {
        startMotionUpdates()
    }
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0  // 60 Hz
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            // Normalize pitch and roll
            // Pitch ranges from -π/2 to π/2, roll from -π to π
            var newPitch = motion.attitude.pitch / (.pi / 2)
            var newRoll = motion.attitude.roll / .pi
            
            // Clamp pitch to -1...1, roll to -0.5...0.5
            newPitch = max(-1, min(1, newPitch))
            newRoll = max(-0.5, min(0.5, newRoll))
            
            // Update published values for UI
            self.pitch = newPitch
            self.roll = newRoll
            
            // Call direct callbacks for audio (bypasses SwiftUI update cycle)
            self.onPitchUpdate?(newPitch)
            self.onRollUpdate?(newRoll)
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    deinit {
        stopMotionUpdates()
    }
}

// MARK: - Rhythm Helpers
struct RhythmHelper {
    // Standard subdivisions with their beat multipliers
    static let subdivisions: [(name: String, beats: Double)] = [
        ("1/1", 4.0),      // Whole note
        ("1/2", 2.0),      // Half note
        ("1/4", 1.0),      // Quarter note
        ("1/8", 0.5),      // Eighth note
        ("1/16", 0.25),    // Sixteenth note
        ("1/32", 0.125),   // 32nd note
        ("1/4T", 2.0/3.0), // Quarter triplet
        ("1/8T", 1.0/3.0), // Eighth triplet
        ("1/16T", 1.0/6.0) // Sixteenth triplet
    ]
    
    /// Convert BPM and subdivision to rate in seconds
    static func subdivisionToRate(bpm: Double, subdivision: String) -> Double {
        let secondsPerBeat = 60.0 / bpm
        if let sub = subdivisions.first(where: { $0.name == subdivision }) {
            return secondsPerBeat * sub.beats
        }
        return secondsPerBeat  // Default to quarter note
    }
    
    /// Find the closest subdivision for a given rate at a specific BPM
    static func rateToSubdivision(rate: Double, bpm: Double) -> String {
        let secondsPerBeat = 60.0 / bpm
        var closestSub = "1/4"
        var smallestDiff = Double.infinity
        
        for sub in subdivisions {
            let subRate = secondsPerBeat * sub.beats
            let diff = abs(rate - subRate)
            if diff < smallestDiff {
                smallestDiff = diff
                closestSub = sub.name
            }
        }
        return closestSub
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var bpm: Double
    @Binding var theme: AppTheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Theme Selection
                        VStack(spacing: 12) {
                            Text("Theme")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            HStack(spacing: 12) {
                                ForEach(AppTheme.allCases, id: \.self) { themeOption in
                                    Button(action: { theme = themeOption }) {
                                        VStack(spacing: 6) {
                                            // Theme preview circle
                                            ZStack {
                                                Circle()
                                                    .fill(themeOption.background)
                                                    .frame(width: 50, height: 50)
                                                Circle()
                                                    .stroke(theme == themeOption ? themeOption.accent : Color.gray.opacity(0.3), lineWidth: 3)
                                                    .frame(width: 50, height: 50)
                                                // Mini color dots
                                                HStack(spacing: 2) {
                                                    Circle().fill(themeOption.decay).frame(width: 8, height: 8)
                                                    Circle().fill(themeOption.waveform).frame(width: 8, height: 8)
                                                    Circle().fill(themeOption.keyFX).frame(width: 8, height: 8)
                                                }
                                            }
                                            Text(themeOption.rawValue)
                                                .font(.caption)
                                                .fontWeight(theme == themeOption ? .bold : .regular)
                                                .foregroundColor(theme == themeOption ? theme.accent : theme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.textPrimary.opacity(0.05))
                        )
                        .padding(.horizontal)
                        
                        // BPM Control
                        VStack(spacing: 8) {
                            Text("BPM")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            HStack {
                                Button(action: { bpm = max(20, bpm - 1) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(theme.accent)
                                }
                                
                                Text("\(Int(bpm))")
                                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                                    .foregroundColor(theme.textPrimary)
                                    .frame(width: 120)
                                
                                Button(action: { bpm = min(300, bpm + 1) }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(theme.accent)
                                }
                            }
                            
                            Slider(value: $bpm, in: 20...300, step: 1)
                                .tint(theme.accent)
                                .padding(.horizontal, 40)
                            
                            // Preset BPM buttons
                            HStack(spacing: 12) {
                                ForEach([60, 90, 120, 140], id: \.self) { preset in
                                    Button(action: { bpm = Double(preset) }) {
                                        Text("\(preset)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(Int(bpm) == preset ? theme.background : theme.accent)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Int(bpm) == preset ? theme.accent : theme.accent.opacity(0.2))
                                            )
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.textPrimary.opacity(0.05))
                        )
                        .padding(.horizontal)
                        
                        // Info text
                        VStack(spacing: 4) {
                            Text("Tap Rate value to toggle subdivision sync")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                            Text("Tap Frequency value to show note name")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
            .modifier(DarkToolbarModifier())
        }
    }
}

// iOS version-safe toolbar styling
struct DarkToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            content
                .onAppear {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = .black
                    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                    UINavigationBar.appearance().standardAppearance = appearance
                    UINavigationBar.appearance().scrollEdgeAppearance = appearance
                }
        }
    }
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var audioManager = AudioManager()
    
    @State private var waveformValue: Double = 0.17  // 0=sine, 0.33=tri, 0.66=saw, 1=square
    @State private var rateLocked: Bool = false
    @State private var frequencyLocked: Bool = false
    @State private var selectedRoot: RootNote = .c
    @State private var selectedScale: ScaleType = .off
    @State private var chordMode: Bool = false
    
    // Settings
    @State private var showSettings: Bool = false
    @State private var bpm: Double = 120.0
    @State private var currentTheme: AppTheme = .midnight
    
    // Display mode toggles
    @State private var showRateAsSubdivision: Bool = false
    @State private var showFrequencyAsNote: Bool = false
    
    // ADSR envelope
    @State private var attackTime: Double = 0.01
    @State private var decayTime: Double = 0.1
    @State private var sustainLevel: Double = 0.7
    @State private var releaseTime: Double = 0.2
    
    // Legato mode
    @State private var legatoMode: Bool = false
    
    // Unison, detune, and filter
    @State private var unisonCount: Int = 1
    @State private var detuneAmount: Double = 0.0
    @State private var filterCutoff: Double = 1.0
    
    // Key tolerance
    @State private var keyTolerance: Double = 25.0
    
    // Module expand/collapse state
    @State private var isDecayExpanded: Bool = false
    @State private var isWaveformExpanded: Bool = false
    @State private var isKeyFXExpanded: Bool = false
    
    // Custom ranges
    @State private var freqRangeLow: Double = 50.0
    @State private var freqRangeHigh: Double = 1000.0
    @State private var rateRangeLow: Double = 0.01
    @State private var rateRangeHigh: Double = 0.5
    
    // Oscilloscope
    @State private var oscilloscopeSamples: [Float] = []
    let oscilloscopeTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            currentTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 6) {
                // Oscilloscope
                OscilloscopeView(samples: oscilloscopeSamples, height: 80, lineColor: currentTheme.oscilloscope)
                    .padding(.horizontal, 20)
                    .onReceive(oscilloscopeTimer) { _ in
                        oscilloscopeSamples = audioManager.oscilloscopeSamples
                    }
                
                // Rate, Level Indicator, and Frequency in one row
                HStack(spacing: 8) {
                    // Rate (left side)
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Rate")
                                .font(.caption2)
                                .foregroundColor(legatoMode ? currentTheme.textSecondary.opacity(0.5) : currentTheme.textSecondary)
                            Button(action: {
                                rateLocked.toggle()
                                audioManager.rateLocked = rateLocked
                            }) {
                                Image(systemName: rateLocked ? "lock.fill" : "lock.open")
                                    .font(.caption2)
                                    .foregroundColor(rateLocked ? currentTheme.levelIndicatorWarn : currentTheme.textSecondary)
                            }
                            .disabled(legatoMode)
                            .opacity(legatoMode ? 0.3 : 1.0)
                        }
                        if legatoMode {
                            Text("Legato")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(currentTheme.decay)
                        } else {
                            Button(action: {
                                showRateAsSubdivision.toggle()
                                audioManager.rateSyncedToTempo = showRateAsSubdivision
                            }) {
                                if showRateAsSubdivision {
                                    Text(RhythmHelper.rateToSubdivision(rate: rateFromPitch, bpm: bpm))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(currentTheme.accent)
                                } else {
                                    Text("\(rateFromPitch, specifier: "%.2f")s")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(currentTheme.textPrimary)
                                        .monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    // Level indicator (center)
                    LevelIndicator(
                        pitch: motionManager.pitch,
                        roll: motionManager.roll,
                        size: 55,
                        theme: currentTheme
                    )
                    
                    // Frequency (right side)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Button(action: {
                                frequencyLocked.toggle()
                                audioManager.frequencyLocked = frequencyLocked
                            }) {
                                Image(systemName: frequencyLocked ? "lock.fill" : "lock.open")
                                    .font(.caption2)
                                    .foregroundColor(frequencyLocked ? currentTheme.levelIndicatorWarn : currentTheme.textSecondary)
                            }
                            Text("Freq")
                                .font(.caption2)
                                .foregroundColor(currentTheme.textSecondary)
                        }
                        Button(action: { showFrequencyAsNote.toggle() }) {
                            if showFrequencyAsNote {
                                Text(KeyQuantizer.frequencyToNoteName(frequencyFromRoll))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(currentTheme.freqRange)
                            } else {
                                Text("\(frequencyFromRoll, specifier: "%.1f")Hz")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(currentTheme.textPrimary)
                                    .monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                
                // Decay module (now full ADSR)
                VStack(spacing: 1) {
                    // Header (tappable)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDecayExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Decay")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(currentTheme.decay)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(currentTheme.decay.opacity(0.7))
                                .rotationEffect(.degrees(isDecayExpanded ? 90 : 0))
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Main slider (Release time as the primary "decay" control)
                    HStack {
                        Text("Short")
                            .font(.caption2)
                            .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                        Spacer()
                        Text("Long")
                            .font(.caption2)
                            .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                    }
                    Slider(value: $releaseTime, in: 0.01...2.0)
                        .tint(currentTheme.decay)
                        .onChange(of: releaseTime) { newValue in
                            audioManager.releaseTime = newValue
                        }
                    
                    // Expanded details (full ADSR + Legato)
                    if isDecayExpanded {
                        VStack(spacing: 6) {
                            // Legato toggle
                            HStack {
                                Text("Legato")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.textPrimary.opacity(0.8))
                                Spacer()
                                Toggle("", isOn: $legatoMode)
                                    .labelsHidden()
                                    .tint(currentTheme.decay)
                                    .onChange(of: legatoMode) { newValue in
                                        if newValue {
                                            // Max sustain for legato mode
                                            sustainLevel = 1.0
                                            audioManager.sustainLevel = 1.0
                                            audioManager.startLegato()
                                        } else {
                                            audioManager.stopLegato()
                                            audioManager.startBeeping()
                                        }
                                    }
                            }
                            
                            // Attack slider
                            HStack {
                                Text("A")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(currentTheme.decay.opacity(0.8))
                                    .frame(width: 16)
                                Slider(value: $attackTime, in: 0.001...1.0)
                                    .tint(currentTheme.decay.opacity(0.7))
                                    .onChange(of: attackTime) { newValue in
                                        audioManager.attackTime = newValue
                                    }
                                Text("\(Int(attackTime * 1000))ms")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.decay.opacity(0.6))
                                    .monospacedDigit()
                                    .frame(width: 45, alignment: .trailing)
                            }
                            
                            // Decay slider
                            HStack {
                                Text("D")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(currentTheme.decay.opacity(0.8))
                                    .frame(width: 16)
                                Slider(value: $decayTime, in: 0.01...1.0)
                                    .tint(currentTheme.decay.opacity(0.7))
                                    .onChange(of: decayTime) { newValue in
                                        audioManager.decayTime = newValue
                                    }
                                Text("\(Int(decayTime * 1000))ms")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.decay.opacity(0.6))
                                    .monospacedDigit()
                                    .frame(width: 45, alignment: .trailing)
                            }
                            
                            // Sustain slider
                            HStack {
                                Text("S")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(currentTheme.decay.opacity(0.8))
                                    .frame(width: 16)
                                Slider(value: $sustainLevel, in: 0...1)
                                    .tint(currentTheme.decay.opacity(0.7))
                                    .onChange(of: sustainLevel) { newValue in
                                        audioManager.sustainLevel = newValue
                                    }
                                Text("\(Int(sustainLevel * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.decay.opacity(0.6))
                                    .monospacedDigit()
                                    .frame(width: 45, alignment: .trailing)
                            }
                            
                            // Release slider
                            HStack {
                                Text("R")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(currentTheme.decay.opacity(0.8))
                                    .frame(width: 16)
                                Slider(value: $releaseTime, in: 0.01...2.0)
                                    .tint(currentTheme.decay.opacity(0.7))
                                    .onChange(of: releaseTime) { newValue in
                                        audioManager.releaseTime = newValue
                                    }
                                Text("\(Int(releaseTime * 1000))ms")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.decay.opacity(0.6))
                                    .monospacedDigit()
                                    .frame(width: 45, alignment: .trailing)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(currentTheme.decay.opacity(0.15))
                )
                .padding(.horizontal, 12)
                
                // Waveform module
                VStack(spacing: 1) {
                    // Header (tappable)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isWaveformExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Waveform")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(currentTheme.waveform)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(currentTheme.waveform.opacity(0.7))
                                .rotationEffect(.degrees(isWaveformExpanded ? 90 : 0))
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Main slider (always visible)
                    HStack {
                        Text("Sine")
                            .font(.caption2)
                            .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                        Spacer()
                        Text("Tri")
                            .font(.caption2)
                            .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                        Spacer()
                        Text("Saw")
                            .font(.caption2)
                            .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                        Spacer()
                        Text("Sq")
                            .font(.caption2)
                            .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                    }
                    Slider(value: $waveformValue, in: 0...1)
                        .tint(currentTheme.waveform)
                        .onChange(of: waveformValue) { newValue in
                            audioManager.waveformMix = newValue
                        }
                    
                    // Expanded details (Unison, Detune, and Filter)
                    if isWaveformExpanded {
                        VStack(spacing: 6) {
                            HStack(spacing: 12) {
                                // Unison picker
                                HStack(spacing: 4) {
                                    Text("Unison")
                                        .font(.caption2)
                                        .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                                    Picker("Unison", selection: $unisonCount) {
                                        Text("1x").tag(1)
                                        Text("2x").tag(2)
                                        Text("3x").tag(3)
                                        Text("5x").tag(5)
                                    }
                                    .pickerStyle(.menu)
                                    .tint(currentTheme.waveform)
                                    .onChange(of: unisonCount) { newValue in
                                        audioManager.unisonCount = newValue
                                    }
                                }
                                
                                // Detune slider
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("Detune")
                                            .font(.caption2)
                                            .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                                        Spacer()
                                        Text("\(Int(detuneAmount))¢")
                                            .font(.caption2)
                                            .foregroundColor(currentTheme.waveform.opacity(0.7))
                                            .monospacedDigit()
                                    }
                                    Slider(value: $detuneAmount, in: 0...50)
                                        .tint(currentTheme.waveform)
                                        .disabled(unisonCount == 1)
                                        .opacity(unisonCount == 1 ? 0.4 : 1.0)
                                        .onChange(of: detuneAmount) { newValue in
                                            audioManager.detuneAmount = newValue
                                        }
                                }
                            }
                            
                            // Filter slider
                            HStack {
                                Text("Filter")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                                    .frame(width: 32, alignment: .leading)
                                Text("Dark")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.waveform.opacity(0.5))
                                Slider(value: $filterCutoff, in: 0...1)
                                    .tint(currentTheme.waveform)
                                    .onChange(of: filterCutoff) { newValue in
                                        audioManager.filterCutoff = newValue
                                    }
                                Text("Bright")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.waveform.opacity(0.5))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(currentTheme.waveform.opacity(0.15))
                )
                .padding(.horizontal, 12)
                
                // KeyFX module
                VStack(spacing: 1) {
                    // Header (tappable)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isKeyFXExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("KeyFX")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(currentTheme.keyFX)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(currentTheme.keyFX.opacity(0.7))
                                .rotationEffect(.degrees(isKeyFXExpanded ? 90 : 0))
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Main controls (always visible)
                    HStack(spacing: 16) {
                        // Key selection
                        VStack(spacing: 2) {
                            Text("Key")
                                .font(.caption2)
                                .foregroundColor(currentTheme.textPrimary.opacity(0.8))
                            
                            HStack(spacing: 4) {
                                Picker("Root", selection: $selectedRoot) {
                                    ForEach(RootNote.allCases, id: \.self) { note in
                                        Text(note.name).tag(note)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(currentTheme.textPrimary)
                                .onChange(of: selectedRoot) { newValue in
                                    audioManager.selectedRoot = newValue
                                }
                                
                                Picker("Scale", selection: $selectedScale) {
                                    ForEach(ScaleType.allCases, id: \.self) { scale in
                                        Text(scale.rawValue).tag(scale)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                                .onChange(of: selectedScale) { newValue in
                                    audioManager.selectedScale = newValue
                                    if newValue == .off {
                                        chordMode = false
                                        audioManager.chordMode = false
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Chord toggle
                        VStack(spacing: 2) {
                            Text("Chord")
                                .font(.caption2)
                                .foregroundColor(selectedScale == .off ? currentTheme.textPrimary.opacity(0.3) : currentTheme.textPrimary.opacity(0.8))
                            Toggle("", isOn: $chordMode)
                                .labelsHidden()
                                .tint(currentTheme.keyFX)
                                .disabled(selectedScale == .off)
                                .onChange(of: chordMode) { newValue in
                                    audioManager.chordMode = newValue
                                    if newValue {
                                        audioManager.updateChordFrequencies()
                                    }
                                }
                        }
                    }
                    
                    // Expanded details (Tolerance)
                    if isKeyFXExpanded {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Tolerance")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.textPrimary.opacity(0.6))
                                Spacer()
                                Text("\(Int(keyTolerance))¢")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.keyFX.opacity(0.7))
                                    .monospacedDigit()
                            }
                            HStack {
                                Text("Snap")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.keyFX.opacity(0.5))
                                Slider(value: $keyTolerance, in: 0...50)
                                    .tint(currentTheme.keyFX)
                                    .disabled(selectedScale == .off)
                                    .opacity(selectedScale == .off ? 0.4 : 1.0)
                                    .onChange(of: keyTolerance) { newValue in
                                        audioManager.keyTolerance = newValue
                                    }
                                Text("Slide")
                                    .font(.caption2)
                                    .foregroundColor(currentTheme.keyFX.opacity(0.5))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(currentTheme.keyFX.opacity(0.15))
                )
                .padding(.horizontal, 12)
                
                // Range sliders row
                HStack(spacing: 12) {
                    // Frequency range
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("Freq")
                                .font(.caption2)
                                .foregroundColor(currentTheme.freqRange)
                            Spacer()
                            Text("\(formatFreq(freqRangeLow))-\(formatFreq(freqRangeHigh))")
                                .font(.caption2)
                                .foregroundColor(currentTheme.freqRange.opacity(0.7))
                                .monospacedDigit()
                        }
                        RangeSlider(
                            lowValue: $freqRangeLow,
                            highValue: $freqRangeHigh,
                            range: AudioConstants.absoluteMinFreq...AudioConstants.absoluteMaxFreq,
                            useLogScale: true,
                            tint: currentTheme.freqRange
                        )
                        .onChange(of: freqRangeLow) { newValue in
                            audioManager.minFrequency = newValue
                        }
                        .onChange(of: freqRangeHigh) { newValue in
                            audioManager.maxFrequency = newValue
                        }
                    }
                    
                    // Rate range
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("Rate")
                                .font(.caption2)
                                .foregroundColor(currentTheme.rateRange)
                            Spacer()
                            Text("\(formatRate(rateRangeLow))-\(formatRate(rateRangeHigh))")
                                .font(.caption2)
                                .foregroundColor(currentTheme.rateRange.opacity(0.7))
                                .monospacedDigit()
                        }
                        RangeSlider(
                            lowValue: $rateRangeLow,
                            highValue: $rateRangeHigh,
                            range: AudioConstants.absoluteMinRate...AudioConstants.absoluteMaxRate,
                            useLogScale: true,
                            tint: currentTheme.rateRange
                        )
                        .onChange(of: rateRangeLow) { newValue in
                            audioManager.minRate = newValue
                        }
                        .onChange(of: rateRangeHigh) { newValue in
                            audioManager.maxRate = newValue
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer(minLength: 0)
            }
            
            // Settings cog (top-right corner)
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(currentTheme.textSecondary)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .padding(.top, 4)
            .padding(.trailing, 8)
        }
        .onAppear {
            // Prevent screen from dimming/sleeping
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Sync initial range values
            audioManager.minFrequency = freqRangeLow
            audioManager.maxFrequency = freqRangeHigh
            audioManager.minRate = rateRangeLow
            audioManager.maxRate = rateRangeHigh
            
            // Sync initial ADSR values
            audioManager.attackTime = attackTime
            audioManager.decayTime = decayTime
            audioManager.sustainLevel = sustainLevel
            audioManager.releaseTime = releaseTime
            
            // Sync filter and tolerance
            audioManager.filterCutoff = filterCutoff
            audioManager.keyTolerance = keyTolerance
            
            // Sync tempo settings
            audioManager.bpm = bpm
            audioManager.rateSyncedToTempo = showRateAsSubdivision
            
            // Wire up direct callbacks from motion to audio (bypasses SwiftUI)
            motionManager.onRollUpdate = { [weak audioManager] roll in
                guard let audioManager = audioManager, !audioManager.frequencyLocked else { return }
                audioManager.updateFrequency(fromRoll: roll)
            }
            motionManager.onPitchUpdate = { [weak audioManager] pitch in
                guard let audioManager = audioManager, !audioManager.rateLocked, !audioManager.legatoMode else { return }
                audioManager.updateRate(fromPitch: pitch)
            }
            audioManager.startBeeping()
        }
        .onDisappear {
            // Re-enable idle timer
            UIApplication.shared.isIdleTimerDisabled = false
            
            audioManager.stopBeeping()
            motionManager.onRollUpdate = nil
            motionManager.onPitchUpdate = nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(bpm: $bpm, theme: $currentTheme)
        }
        .onChange(of: bpm) { newValue in
            audioManager.bpm = newValue
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // Computed values for display
    var rateFromPitch: Double {
        let normalizedPitch = (motionManager.pitch + 1.0) / 2.0  // -1...1 → 0...1
        var rate = rateRangeHigh - (rateRangeHigh - rateRangeLow) * normalizedPitch
        rate = max(rateRangeLow, min(rateRangeHigh, rate))
        
        // Quantize to subdivision if synced to tempo
        if showRateAsSubdivision {
            let subdivision = RhythmHelper.rateToSubdivision(rate: rate, bpm: bpm)
            rate = RhythmHelper.subdivisionToRate(bpm: bpm, subdivision: subdivision)
            rate = max(rateRangeLow, min(rateRangeHigh, rate))
        }
        
        return rate
    }
    
    var frequencyFromRoll: Double {
        let normalizedRoll = motionManager.roll + 0.5  // -0.5...0.5 → 0...1
        let logMin = log(freqRangeLow)
        let logMax = log(freqRangeHigh)
        let logFreq = logMin + (logMax - logMin) * normalizedRoll
        return exp(logFreq)
    }
    
    var waveformLabel: String {
        if waveformValue <= 0.17 {
            return "Sine"
        } else if waveformValue <= 0.5 {
            return "Triangle"
        } else if waveformValue <= 0.83 {
            return "Saw"
        } else {
            return "Square"
        }
    }
    
    // Format frequency for display
    func formatFreq(_ freq: Double) -> String {
        if freq >= 1000 {
            return String(format: "%.1fkHz", freq / 1000)
        } else {
            return String(format: "%.0fHz", freq)
        }
    }
    
    // Format rate for display
    func formatRate(_ rate: Double) -> String {
        if rate < 1 {
            return String(format: "%.0fms", rate * 1000)
        } else {
            return String(format: "%.2fs", rate)
        }
    }
}

#Preview {
    ContentView()
}
