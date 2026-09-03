//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

/// Which folder is being triaged, and the way to change it.
///
/// Reads as a location field so the answer to "where am I?" is always on
/// screen, but it is a menu rather than an editable field: under the
/// sandbox a typed path grants no access at all, so the only routes in are
/// `NSOpenPanel` and a bookmark that panel already minted.
struct FolderField: View {
    let url: URL
    let recents: [URL]
    /// A folder already bookmarked — switch straight to it.
    let onPick: (URL) -> Void
    /// Open the panel for somewhere new.
    let onChoose: () -> Void

    var body: some View {
        Menu {
            Button("Downloads") { onPick(TriageView.defaultDownloadsFolder) }
            if !recents.isEmpty {
                Divider()
                ForEach(recents, id: \.self) { recent in
                    Button(Self.displayPath(for: recent)) { onPick(recent) }
                }
            }
            Divider()
            Button("Choose Folder…") { onChoose() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.unit) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                Text(Self.displayPath(for: url))
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    // A long path loses its middle, never its end — the
                    // folder name is the part that identifies it.
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            .frame(maxWidth: 260, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Triaging \(url.path) — click to switch folders")
    }

    /// `~/Downloads` rather than `/Users/you/Downloads`.
    ///
    /// Cannot use `abbreviatingWithTildeInPath`: in a sandboxed app
    /// `NSHomeDirectory()` is the *container*, not the real home, so the
    /// substitution silently never matches and the field shows a full path.
    /// `getpwuid` reports the real home regardless of the container.
    static func displayPath(for url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard !realHome.isEmpty, path == realHome || path.hasPrefix(realHome + "/") else {
            return path
        }
        return "~" + path.dropFirst(realHome.count)
    }

    private static let realHome: String = {
        guard let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir else { return "" }
        return String(cString: dir)
    }()
}
