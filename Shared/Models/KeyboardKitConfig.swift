//
//  KeyboardKitConfig.swift
//  MurMur
//
//  Created by Niraj Nair on 04/09/25.
//

import KeyboardKit

extension KeyboardApp {
    static var murMur: KeyboardApp {
        .init(
            name: "MurMur",
            appGroupId: "group.com.nirajnair.MurMur",
            locales: [.english],
            deepLinks: .init(
                app: "murmur://",
            )
        )
    }
}
