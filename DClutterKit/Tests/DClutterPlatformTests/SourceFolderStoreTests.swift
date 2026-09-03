//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterPlatform

@Suite("Source folder recents")
struct SourceFolderStoreTests {
    @Test("A new folder goes to the front")
    func newestFirst() {
        let merged = SourceFolderStore.merged(["/a", "/b"], adding: "/c")
        #expect(merged == ["/c", "/a", "/b"])
    }

    @Test("Re-picking a folder promotes it instead of duplicating it")
    func promotesExisting() {
        let merged = SourceFolderStore.merged(["/a", "/b", "/c"], adding: "/c")
        #expect(merged == ["/c", "/a", "/b"])
    }

    @Test("The list is capped")
    func capsAtMaximum() {
        let existing = (1...SourceFolderStore.maximumRecents).map { "/folder\($0)" }
        let merged = SourceFolderStore.merged(existing, adding: "/new")
        #expect(merged.count == SourceFolderStore.maximumRecents)
        #expect(merged.first == "/new")
        #expect(!merged.contains("/folder\(SourceFolderStore.maximumRecents)"))
    }
}
