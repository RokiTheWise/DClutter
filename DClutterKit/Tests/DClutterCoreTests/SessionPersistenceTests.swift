//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterCore

@Suite("Session persistence filenames")
struct SessionPersistenceTests {
    @Test("The same folder always maps to the same file")
    func stableForSameFolder() {
        let folder = URL(fileURLWithPath: "/Users/someone/Downloads")
        #expect(
            SessionPersistence.filename(for: folder)
                == SessionPersistence.filename(for: folder)
        )
    }

    @Test("Different folders never share a session file")
    func distinctForDifferentFolders() {
        let downloads = URL(fileURLWithPath: "/Users/someone/Downloads")
        let desktop = URL(fileURLWithPath: "/Users/someone/Desktop")
        #expect(
            SessionPersistence.filename(for: downloads)
                != SessionPersistence.filename(for: desktop)
        )
    }

    @Test("Trailing slashes and dot segments name the same folder")
    func normalisesEquivalentPaths() {
        let plain = URL(fileURLWithPath: "/Users/someone/Downloads")
        let trailing = URL(fileURLWithPath: "/Users/someone/Downloads/")
        let dotted = URL(fileURLWithPath: "/Users/someone/Music/../Downloads")
        #expect(SessionPersistence.filename(for: plain) == SessionPersistence.filename(for: trailing))
        #expect(SessionPersistence.filename(for: plain) == SessionPersistence.filename(for: dotted))
    }

    @Test("The result is a single usable path component")
    func isASinglePathComponent() {
        let name = SessionPersistence.filename(for: URL(fileURLWithPath: "/Users/someone/Downloads"))
        #expect(!name.contains("/"))
        #expect(name.hasPrefix("session-"))
        #expect(name.hasSuffix(".json"))
    }
}
