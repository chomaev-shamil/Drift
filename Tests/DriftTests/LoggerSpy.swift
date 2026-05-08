import Foundation
@testable import Drift

final class LoggerSpy: NavigationLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [NavigationEvent] = []

    var events: [NavigationEvent] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    func log(_ event: NavigationEvent) {
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }
}
