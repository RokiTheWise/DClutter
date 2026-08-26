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
