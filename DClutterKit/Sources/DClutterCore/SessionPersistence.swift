//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// Where a folder's session state lives.
///
/// One file per source folder, not one file overall. `DClutterSession`
/// reconciles a snapshot against whatever candidates it is handed, so a
/// single fixed `session.json` would apply Downloads' saved decisions to
/// another folder's files the moment the source folder can change.
///
/// Keeping them separate also makes "leave them staged" a coherent answer
/// when switching folders: the staged set stays with the folder it belongs
/// to and is still there when you switch back.
public enum SessionPersistence {
    /// FNV-1a over the normalised path. A hash rather than the path itself
    /// because a path contains `/` and can exceed the filename length
    /// limit; FNV-1a rather than SHA because Core is limited to Foundation
    /// and this needs to be stable, not cryptographic.
    public static func filename(for folder: URL) -> String {
        let path = folder.resolvingSymlinksInPath().standardizedFileURL.path
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return "session-\(String(hash, radix: 16)).json"
    }
}
