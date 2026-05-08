import Testing
@testable import Drift

enum TestIntent: Equatable {
    case openHome
    case openProfile(id: String)
}

@MainActor
struct DeeplinkBufferTests {
    @Test func storesAndConsumes() {
        let buf = DeeplinkBuffer<TestIntent>()
        #expect(buf.hasPending == false)
        buf.store(.openProfile(id: "42"))
        #expect(buf.hasPending == true)
        #expect(buf.consume() == .openProfile(id: "42"))
        #expect(buf.consume() == nil)
    }

    @Test func storeOverwritesPrevious() {
        let buf = DeeplinkBuffer<TestIntent>()
        buf.store(.openHome)
        buf.store(.openProfile(id: "1"))
        #expect(buf.consume() == .openProfile(id: "1"))
    }
}
