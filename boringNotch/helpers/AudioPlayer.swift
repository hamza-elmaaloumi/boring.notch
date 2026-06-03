//
//  AudioPlayer.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 09/08/24.
//

import Foundation
import AppKit

class AudioPlayer {
    func play(fileName: String, fileExtension: String, duration: TimeInterval? = nil) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension),
              let sound = NSSound(contentsOf: url, byReference: false) else { return }

        if let duration = duration {
            sound.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                if sound.isPlaying {
                    sound.stop()
                }
            }
        } else {
            sound.play()
        }
    }
}
