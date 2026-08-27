//
//  DClutterApp.swift
//  DClutter
//
//  Created by Dexter Jethro Enriquez on 8/26/26.
//

import SwiftUI

@main
struct DClutterApp: App {
    var body: some Scene {
        WindowGroup {
            // Design spec §4: minimum 520x640. Below that the card stops
            // being a card — the preview well and metadata rows compress
            // until the layout reads as a cramped list instead.
            ContentView()
                .frame(minWidth: 520, minHeight: 640)
        }
        .defaultSize(width: 720, height: 820)
    }
}
