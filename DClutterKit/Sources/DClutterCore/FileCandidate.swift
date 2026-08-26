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
    public let sourceURL: URL?
    public let contentType: UTType?
    public let isDirectory: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        bytes: Int64,
        lastOpened: Date?,
        created: Date,
        sourceURL: URL? = nil,
        contentType: UTType? = nil,
        isDirectory: Bool = false
    ) {
        self.id = id
        self.url = url
        self.bytes = bytes
        self.lastOpened = lastOpened
        self.created = created
        self.sourceURL = sourceURL
        self.contentType = contentType
        self.isDirectory = isDirectory
    }
}
