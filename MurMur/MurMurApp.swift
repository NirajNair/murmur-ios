//
//  MurMurApp.swift
//  MurMur
//
//  Created by Niraj Nair on 12/08/25.
//

import SwiftUI

@main
struct MurMurApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func handleURL(_ url: URL) {
        if url.scheme == URLSchemeConstants.scheme && url.host == URLSchemeConstants.host {
            let sharedUserDefaults = UserDefaults(
                suiteName: AppGroupConstants.userDefaultsSuiteName)
            if sharedUserDefaults?.bool(forKey: AppGroupConstants.isRecordingKey) == true {
                // We'll implement the recording logic here in the next step
                print("Start recording...")
            }
        }
    }
}
