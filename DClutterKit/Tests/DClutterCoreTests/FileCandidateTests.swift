import Testing
import Foundation
@testable import DClutterCore

@Test func candidateStoresWhatItIsGiven() {
    let now = Date()
    let c = FileCandidate(
        url: URL(fileURLWithPath: "/tmp/example.pdf"),
        bytes: 2_048,
        lastOpened: nil,
        created: now
    )
    #expect(c.bytes == 2_048)
    #expect(c.lastOpened == nil)
}

@Test func candidateModifiedDefaultsToNil() {
    let c = FileCandidate(
        url: URL(fileURLWithPath: "/tmp/example.pdf"),
        bytes: 2_048,
        lastOpened: nil,
        created: Date()
    )
    #expect(c.modified == nil)
}

@Test func candidateStoresModifiedWhenGiven() {
    let modified = Date(timeIntervalSince1970: 1_700_000_000)
    let c = FileCandidate(
        url: URL(fileURLWithPath: "/tmp/example.pdf"),
        bytes: 2_048,
        lastOpened: nil,
        created: Date(),
        modified: modified
    )
    #expect(c.modified == modified)
}

@Test(arguments: [
    "IMG_1234.jpg",
    "IMG-20230101-WA0001.jpg",
    "DSC_0001.jpg",
    "Screenshot 2024-01-01 at 10.00.00 AM.png",
    "Screen Shot 2024-01-01 at 10.00.00 AM.png",
    "download.zip",
    "download (2).zip",
    "Downloads.csv",
    "Untitled.pages",
    "Untitled 2.numbers",
    "New Document.pdf",
    "Document.pdf",
    "Document 3.pdf",
    "unnamed.txt",
    "scan0001.pdf",
    "Scan 2024-01-01.pdf",
    "file.txt",
    "1234567.pdf",
])
func genericNamesAreDetected(name: String) {
    let c = FileCandidate(
        url: URL(fileURLWithPath: "/tmp/\(name)"),
        bytes: 1_024,
        lastOpened: nil,
        created: Date()
    )
    #expect(c.hasGenericName, "expected \(name) to be flagged generic")
}

@Test(arguments: [
    "Quarterly Report Q3.pdf",
    "Project Proposal - Acme Corp.docx",
    "vacation-photo-hawaii.jpg",
    "eecs101-lecture-notes.pdf",
    "Cards.zip",
    "invoice_10293.pdf",
])
func descriptiveNamesAreNotGeneric(name: String) {
    let c = FileCandidate(
        url: URL(fileURLWithPath: "/tmp/\(name)"),
        bytes: 1_024,
        lastOpened: nil,
        created: Date()
    )
    #expect(!c.hasGenericName, "expected \(name) to NOT be flagged generic")
}
