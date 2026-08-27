import Testing
import Foundation
@testable import DClutterCore

@Test func fileStateRoundTripsThroughJSON() throws {
    let states: [FileState] = [.pending, .kept, .staged, .trashed, .moved(to: URL(fileURLWithPath: "/tmp/x"))]
    let data = try JSONEncoder().encode(states)
    let decoded = try JSONDecoder().decode([FileState].self, from: data)
    #expect(decoded == states)
}
