//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation
import UniformTypeIdentifiers

/// A single file under consideration, stripped of any platform specifics.
///
/// `lastOpened` is optional by design: Windows disables last-access-time
/// tracking by default, so any future port returns nil here. Scoring must
/// already handle that case rather than having it retrofitted.
public struct FileCandidate: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let bytes: Int64
    public let lastOpened: Date?
    public let created: Date
    /// Filesystem modification time. Falls back point for staleness when
    /// `lastOpened` is unavailable — see QueueScorer.
    public let modified: Date?
    public let sourceURL: URL?
    public let contentType: UTType?
    public let isDirectory: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        bytes: Int64,
        lastOpened: Date?,
        created: Date,
        modified: Date? = nil,
        sourceURL: URL? = nil,
        contentType: UTType? = nil,
        isDirectory: Bool = false
    ) {
        self.id = id
        self.url = url
        self.bytes = bytes
        self.lastOpened = lastOpened
        self.created = created
        self.modified = modified
        self.sourceURL = sourceURL
        self.contentType = contentType
        self.isDirectory = isDirectory
    }

    /// Whether the filename looks auto-generated rather than user-chosen —
    /// camera/screenshot patterns, bare "download"/"untitled"/"document",
    /// or a purely numeric name. Feeds the §4 ambiguous-name penalty, which
    /// only applies alongside a missing source URL.
    public var hasGenericName: Bool {
        let stem = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespaces)
        guard !stem.isEmpty else { return true }

        if stem.range(of: #"^\d+$"#, options: .regularExpression) != nil {
            return true
        }

        let patterns = [
            #"^img[_-]?\d+$"#,
            #"^img[_-].*$"#,
            #"^dsc[_-]?\d+$"#,
            #"^screenshot.*$"#,
            #"^screen ?shot.*$"#,
            #"^download(s)?( ?\(\d+\))?$"#,
            #"^untitled( \d+)?$"#,
            #"^new document( \d+)?$"#,
            #"^document( \d+)?$"#,
            #"^unnamed( \d+)?$"#,
            #"^scan ?\d*.*$"#,
            #"^file( \d+)?$"#,
        ]
        return patterns.contains { pattern in
            stem.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
