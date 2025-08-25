//
//  ContentView.swift
//  AppOne
//
//  Created by john davis on 8/25/25.
//

import SwiftUI
// This is from the shared folder in this workspace
import SharedKit

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("AppOne")
            Text("Shared: " + AppInfo.prettyName())
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { Log.info("AppOne appeared")}
    }
}

#Preview {
    ContentView()
}
