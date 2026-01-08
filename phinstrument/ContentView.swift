//
//  ContentView.swift
//  phinstrument
//
//  Created by Dean Eby on 1/8/26.
//


import SwiftUI
import AVFoundation
import AudioToolbox



struct ContentView: View {
    // 1. Define the state
    @State private var isBlack: Bool = false

    @State private var player: AVAudioPlayer?

    func playSound() {
        // 1. Find the path to your file in the app bundle
        guard let url = Bundle.main.url(forResource: "toggle_sound", withExtension: "mp3") else { return }

        do {
            // 2. Initialize and play
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    var body: some View {
        // 2. Use a layout container that fills the space
        ZStack {
            // 3. Set background color based on state
            (isBlack ? Color.blue : Color.pink)
                .ignoresSafeArea()  // Ensures color covers the notch/status bar
        }
        // 4. Add the interaction listener
        .onTapGesture {
            isBlack.toggle()
            playSound()
            AudioServicesPlaySystemSound(1104)
        }
    }
    
}

#Preview {
    ContentView()
}
