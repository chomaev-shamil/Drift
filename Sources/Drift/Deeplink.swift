import Foundation

/// Parses an inbound `URL` into a typed intent your coordinator understands.
///
/// Drift does not impose a URL schema — define one that suits your app and
/// implement this protocol once.
public protocol DeeplinkParsing: Sendable {
    associatedtype Output
    func parse(_ url: URL) -> Output?
}

/// Receives parsed deeplink intents and routes them to the correct flow.
public protocol DeeplinkHandling: AnyObject {
    associatedtype Intent
    @MainActor func handle(_ intent: Intent)
}

/// Latest-wins buffer for an intent that arrives before the app is ready.
///
/// Use this to hold a deeplink while the user is on the auth or onboarding
/// screen; consume it immediately after the user reaches the main flow.
@MainActor
public final class DeeplinkBuffer<Intent> {
    private var pending: Intent?

    public init() {}

    /// Stores an intent, replacing any previously buffered one.
    public func store(_ intent: Intent) { pending = intent }

    /// Returns the buffered intent (if any) and clears the buffer.
    public func consume() -> Intent? { defer { pending = nil }; return pending }

    /// `true` if an intent is currently buffered.
    public var hasPending: Bool { pending != nil }
}
