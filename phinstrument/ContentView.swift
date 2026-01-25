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

// MARK: - Audio Constants
struct AudioConstants {
    // Absolute limits for sliders
    static let absoluteMinFreq: Double = 20.0       // 20 Hz
    static let absoluteMaxFreq: Double = 20000.0    // 20 kHz
    static let absoluteMinInterval: Double = 0.01   // 10ms
    static let absoluteMaxInterval: Double = 3.0    // 3 seconds
    
    static let attackDuration: Double = 0.003  // 3ms attack
    static let pluckDuration: Double = 0.2     // Total pluck duration
    static let sampleRate: Double = 44100.0
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
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 6)
                
                // Selected range
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint)
                    .frame(width: highPosition - lowPosition, height: 6)
                    .offset(x: lowPosition)
                
                // Low thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(radius: 2)
                    .offset(x: lowPosition - 12)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = max(0, min(value.location.x, highPosition - 20))
                                lowValue = positionToValue(newPos, in: width)
                            }
                    )
                
                // High thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(radius: 2)
                    .offset(x: highPosition - 12)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = max(lowPosition + 20, min(value.location.x, width))
                                highValue = positionToValue(newPos, in: width)
                            }
                    )
            }
        }
        .frame(height: 30)
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

// MARK: - Audio Manager
class AudioManager: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var sourceNode: AVAudioSourceNode?
    
    // Thread-safe state using atomic-like pattern
    private var _currentFrequency: Double = 220.0  // A3 - middle of range, easily audible
    private var _samplesSincePluck: Int = Int.max  // Start silent
    private let pluckDurationSamples: Int
    private let attackSamples: Int
    
    private var beepTimer: Timer?
    private var currentInterval: Double = 0.5
    
    // User-adjustable parameters
    var decayFactor: Double = 5.0      // Higher = faster decay (range: 1-15)
    var waveformMix: Double = 0.0      // 0=sine, 0.33=triangle, 0.66=saw, 1=square
    var frequencyLocked: Bool = false
    var intervalLocked: Bool = false
    
    // Custom ranges
    var minFrequency: Double = 100.0    // Low end of frequency range
    var maxFrequency: Double = 1000.0   // High end of frequency range
    var minInterval: Double = 0.1       // Fast end of interval range
    var maxInterval: Double = 1.0       // Slow end of interval range
    
    var currentFrequency: Double {
        get { _currentFrequency }
        set { _currentFrequency = newValue }
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
        pluckDurationSamples = Int(AudioConstants.pluckDuration * AudioConstants.sampleRate)
        attackSamples = Int(AudioConstants.attackDuration * AudioConstants.sampleRate)
        audioEngine = AVAudioEngine()
        
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
        var phase: Double = 0.0
        
        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first,
                  let bufferPointer = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            
            let frequency = self._currentFrequency
            let phaseIncrement = 2.0 * Double.pi * frequency / sampleRate
            let pluckDuration = self.pluckDurationSamples
            let attack = self.attackSamples
            
            let decay = self.decayFactor
            
            for frame in 0..<Int(frameCount) {
                var sample: Float = 0.0
                
                let sampleIndex = self._samplesSincePluck
                if sampleIndex < pluckDuration {
                    var envelope: Double
                    
                    if sampleIndex < attack {
                        // Attack phase: linear ramp from 0 to 1
                        envelope = Double(sampleIndex) / Double(attack)
                    } else {
                        // Decay phase: exponential decay from 1 to 0
                        let decayIndex = sampleIndex - attack
                        let decayDuration = pluckDuration - attack
                        let progress = Double(decayIndex) / Double(decayDuration)
                        envelope = exp(-progress * decay)
                    }
                    
                    // Generate waveform with envelope
                    let waveform = self.generateWaveform(phase: phase)
                    sample = Float(waveform * envelope * 0.8)
                    
                    self._samplesSincePluck += 1
                }
                
                bufferPointer[frame] = sample
                
                phase += phaseIncrement
                if phase >= 2.0 * Double.pi {
                    phase -= 2.0 * Double.pi
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
    
    /// Trigger a pluck sound
    func pluck() {
        _samplesSincePluck = 0  // Reset to start of envelope
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
        
        _currentFrequency = exp(logFreq)
    }
    
    /// Update the beep interval based on pitch value (-1 to 1)
    /// Forward (positive) = fast, Backward (negative) = slow
    func updateInterval(fromPitch pitch: Double) {
        // Map pitch to custom interval range
        // pitch 1 (forward) = minInterval (fast), pitch -1 (back) = maxInterval (slow)
        let normalizedPitch = (pitch + 1.0) / 2.0  // Convert to 0...1
        
        // Linear interpolation: 0 = maxInterval (slow), 1 = minInterval (fast)
        currentInterval = maxInterval - (maxInterval - minInterval) * normalizedPitch
        
        // Clamp to valid range
        currentInterval = max(minInterval, min(maxInterval, currentInterval))
        
        // Don't restart timer here - just update the interval value
        // The timer will use the new value on its next schedule
    }
    
    private func scheduleNextPluck() {
        beepTimer?.invalidate()
        beepTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: false) { [weak self] _ in
            self?.pluck()
            self?.scheduleNextPluck()  // Schedule the next one with current interval
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

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var audioManager = AudioManager()
    
    @State private var decayValue: Double = 5.0       // 1 (slow) to 15 (fast)
    @State private var waveformValue: Double = 0.0   // 0=sine, 0.33=tri, 0.66=saw, 1=square
    @State private var intervalLocked: Bool = false
    @State private var frequencyLocked: Bool = false
    
    // Custom ranges
    @State private var freqRangeLow: Double = 100.0
    @State private var freqRangeHigh: Double = 1000.0
    @State private var intervalRangeLow: Double = 0.1
    @State private var intervalRangeHigh: Double = 1.0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Interval - prominent at top
                    HStack {
                    Text("Interval:")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("\(intervalFromPitch, specifier: "%.2f")s")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(minWidth: 120, alignment: .trailing)
                    Button(action: {
                        intervalLocked.toggle()
                        audioManager.intervalLocked = intervalLocked
                    }) {
                        Image(systemName: intervalLocked ? "lock.fill" : "lock.open")
                            .font(.title2)
                            .foregroundColor(intervalLocked ? .yellow : .gray)
                    }
                }
                
                // Frequency - prominent
                HStack {
                    Text("Freq:")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("\(frequencyFromRoll, specifier: "%.1f") Hz")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(minWidth: 160, alignment: .trailing)
                    Button(action: {
                        frequencyLocked.toggle()
                        audioManager.frequencyLocked = frequencyLocked
                    }) {
                        Image(systemName: frequencyLocked ? "lock.fill" : "lock.open")
                            .font(.title2)
                            .foregroundColor(frequencyLocked ? .yellow : .gray)
                    }
                }
                
                Spacer().frame(height: 10)
                
                // Raw motion values - smaller, less prominent
                HStack(spacing: 30) {
                    Text("Pitch: \(motionManager.pitch, specifier: "%.2f")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Roll: \(motionManager.roll, specifier: "%.2f")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer().frame(height: 20)
                
                // Decay slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Decay: \(decayValue, specifier: "%.1f")")
                        .font(.headline)
                        .foregroundColor(.white)
                    Slider(value: $decayValue, in: 1...15)
                        .tint(.orange)
                        .onChange(of: decayValue) { newValue in
                            audioManager.decayFactor = newValue
                        }
                    HStack {
                        Text("Slow")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Fast")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 30)
                
                // Waveform slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Waveform: \(waveformLabel)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Slider(value: $waveformValue, in: 0...1)
                        .tint(.cyan)
                        .onChange(of: waveformValue) { newValue in
                            audioManager.waveformMix = newValue
                        }
                    HStack {
                        Text("Sine")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Tri")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Saw")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Square")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer().frame(height: 10)
                
                // Frequency range slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Freq Range: \(formatFreq(freqRangeLow)) - \(formatFreq(freqRangeHigh))")
                        .font(.headline)
                        .foregroundColor(.white)
                    RangeSlider(
                        lowValue: $freqRangeLow,
                        highValue: $freqRangeHigh,
                        range: AudioConstants.absoluteMinFreq...AudioConstants.absoluteMaxFreq,
                        useLogScale: true,
                        tint: .green
                    )
                    .onChange(of: freqRangeLow) { newValue in
                        audioManager.minFrequency = newValue
                    }
                    .onChange(of: freqRangeHigh) { newValue in
                        audioManager.maxFrequency = newValue
                    }
                    HStack {
                        Text("20 Hz")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("20 kHz")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 30)
                
                // Interval range slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interval Range: \(formatInterval(intervalRangeLow)) - \(formatInterval(intervalRangeHigh))")
                        .font(.headline)
                        .foregroundColor(.white)
                    RangeSlider(
                        lowValue: $intervalRangeLow,
                        highValue: $intervalRangeHigh,
                        range: AudioConstants.absoluteMinInterval...AudioConstants.absoluteMaxInterval,
                        useLogScale: true,
                        tint: .purple
                    )
                    .onChange(of: intervalRangeLow) { newValue in
                        audioManager.minInterval = newValue
                    }
                    .onChange(of: intervalRangeHigh) { newValue in
                        audioManager.maxInterval = newValue
                    }
                    HStack {
                        Text("10ms")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("3s")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer().frame(height: 30)
            }
            .padding(.vertical, 40)
            }
        }
        .onAppear {
            // Prevent screen from dimming/sleeping
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Sync initial range values
            audioManager.minFrequency = freqRangeLow
            audioManager.maxFrequency = freqRangeHigh
            audioManager.minInterval = intervalRangeLow
            audioManager.maxInterval = intervalRangeHigh
            
            // Wire up direct callbacks from motion to audio (bypasses SwiftUI)
            motionManager.onRollUpdate = { [weak audioManager] roll in
                guard let audioManager = audioManager, !audioManager.frequencyLocked else { return }
                audioManager.updateFrequency(fromRoll: roll)
            }
            motionManager.onPitchUpdate = { [weak audioManager] pitch in
                guard let audioManager = audioManager, !audioManager.intervalLocked else { return }
                audioManager.updateInterval(fromPitch: pitch)
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
    }
    
    // Computed values for display
    var intervalFromPitch: Double {
        let normalizedPitch = (motionManager.pitch + 1.0) / 2.0  // -1...1 → 0...1
        let interval = intervalRangeHigh - (intervalRangeHigh - intervalRangeLow) * normalizedPitch
        return max(intervalRangeLow, min(intervalRangeHigh, interval))
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
    
    // Format interval for display
    func formatInterval(_ interval: Double) -> String {
        if interval < 1 {
            return String(format: "%.0fms", interval * 1000)
        } else {
            return String(format: "%.2fs", interval)
        }
    }
}

#Preview {
    ContentView()
}
