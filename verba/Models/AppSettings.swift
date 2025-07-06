//
//  AppSettings.swift
//  verba
//
//  Created by Chandu Korubilli on 7/6/25.
//
import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var useHighQualityAudio: Bool = true
    @Published var useLocalTranscriptionFallback: Bool = true
    @Published var themeMode: ThemeMode = .system

    enum ThemeMode: String, CaseIterable, Identifiable {
        case light, dark, system

        var id: String { rawValue }
        var label: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
}

