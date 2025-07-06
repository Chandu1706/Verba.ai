//
//  About.swift
//  verba
//
//  Created by Chandu Korubilli on 7/6/25.
//
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("About Verba.ai")
                .font(.largeTitle)
                .bold()

            Text("""
Verba.ai is an AI-powered audio transcription tool. It records audio with built-in noise reduction and enhancement, and provides fast transcription using both online and offline engines.

Developer
Chandu Korubilli
""")
                .font(.body)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding()
        .navigationTitle("About")
    }
}

