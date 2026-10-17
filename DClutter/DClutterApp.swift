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
            // The header and decision row stay visible down to 520×640;
            // the preview grows with the available workspace height.
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
        .commands {
            // SwiftUI gives every WindowGroup a File > New Window on ⌘N,
            // which shadowed the app's own binding for adding a destination
            // folder. A second window on the same queue would be wrong
            // anyway — two views onto one session, each with its own undo.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
