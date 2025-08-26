//
//  ContentView.swift
//  AppTwo
//
//  Created by john davis on 8/25/25.
//

import SwiftUI
// from shared code in this repo
import SharedKit
// from the other shared library
import MySharedLib

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("AppTwo")
            Text("Shared: " + AppInfo.prettyName())
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            Log.info("AppTwo appeared")
            Log.error(MySharedLibrary.testy())
            Log.warn("warn")
            Log.info("info")
        }
    }
}

#Preview {
    ContentView()
}
