import Foundation

/// Sink for navigation events emitted by a ``FlowRouter``.
///
/// Plug in your analytics or os.Logger here. Implementations must be
/// `Sendable` and may be invoked from `@MainActor` only.
public protocol NavigationLogger: Sendable {
    func log(_ event: NavigationEvent)
}

/// Discrete navigation actions a router emits.
public enum NavigationEvent: Sendable, Equatable {
    case push(route: String)
    case pop(route: String?)
    case popToRoot
    case replaceStack(count: Int)
    case present(route: String, style: PresentationStyle)
    case dismiss(route: String?)
}

/// A no-op logger used as the default. Suitable for tests and silent builds.
public struct NoopNavigationLogger: NavigationLogger {
    public init() {}
    public func log(_ event: NavigationEvent) {}
}
