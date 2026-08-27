//
//  ContentView.swift
//  DClutter
//

import SwiftUI
import DClutterUI

struct ContentView: View {
    var body: some View {
        TriageView(folder: Self.downloadsFolder)
    }

    /// In a sandboxed app, `homeDirectoryForCurrentUser` returns the
    /// container path (~/Library/Containers/dev.djenriquez.DClutter/Data),
    /// not the real home — appending "Downloads" to it would scan an empty
    /// folder inside the container. `.downloadsDirectory` is what the
    /// `com.apple.security.files.downloads.read-write` entitlement (§7)
    /// resolves to the real ~/Downloads.
    ///
    /// Note it resolves to a *symlink* into the real folder, not the folder
    /// itself; `DirectoryMetadataProvider` resolves that, since the
    /// URL-based directory enumeration refuses to follow symlinks.
    private static var downloadsFolder: URL {
        (try? FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }
}

#Preview {
    ContentView()
}
