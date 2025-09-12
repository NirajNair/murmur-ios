//
//  MurMurApp.swift
//  MurMur
//
//  Created by Niraj Nair on 12/08/25.
//

import KeyboardKit
import SwiftUI

@main
struct MurMurApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager()

    var body: some Scene {
        WindowGroup {
            KeyboardAppView(for: .murMur) {
                ContentView()
                    .environmentObject(deepLinkManager)
                    .onOpenURL { url in
                        deepLinkManager.handleURL(url)
                    }
            }
        }
    }
}
