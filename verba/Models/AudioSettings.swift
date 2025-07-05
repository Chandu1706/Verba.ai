//
//  AudioSettings.swift
//  verba
//
//  Created by Chandu Korubilli on 7/5/25.
//

import Foundation
import AVFoundation

struct AudioSettings {
    static let sampleRate: Double = 44100.0
    static let formatID: AudioFormatID = kAudioFormatLinearPCM
    static let bitDepth: Int = 16
    static let numberOfChannels: Int = 1

    static var avSettings: [String: Any] {
        return [
            AVFormatIDKey: formatID,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: numberOfChannels,
            AVLinearPCMBitDepthKey: bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
    }
}
