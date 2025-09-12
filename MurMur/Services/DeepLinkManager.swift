//
//  DeepLinkManager.swift
//  MurMur
//
//  Created by Niraj Nair on 04/09/25.
//

import Foundation
import SwiftUI

class DeepLinkManager: ObservableObject {
    @Published var shouldStartRecording = false
    @Published var shouldReturnToHost = false

    func handleURL(_ url: URL) {
        guard url.scheme == "murmur" else { return }
        switch url.host {
        case "startRecording":
            shouldStartRecording = true
        case "returnToHost":
            shouldReturnToHost = true
        default:
            break
        }
    }
}
