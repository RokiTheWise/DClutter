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
            // Sized to fit its contents rather than floating the card in a
            // large canvas: the card caps at 620pt plus a 48pt margin each
            // side, so ~716 is the width at which the layout is exactly
            // itself. Design §4 wants generous margin, not a void.
            ContentView()
                .frame(
                    minWidth: 520, idealWidth: 716,
                    minHeight: 640, idealHeight: 880
                )
        }
        .defaultSize(width: 716, height: 880)
        // Enforces the minimum but still lets the window be resized —
        // .contentSize would pin it exactly and fight the layout's Spacers.
        .windowResizability(.contentMinSize)
    }
}
