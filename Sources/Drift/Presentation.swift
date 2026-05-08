import Foundation

/// How a route is presented over the current screen.
public enum PresentationStyle: Sendable, Equatable {
    /// Card-style sheet. Dismissable by swipe on iOS.
    case sheet
    /// Edge-to-edge cover. Not user-dismissable; close it programmatically.
    case fullScreen
}

/// A route currently presented modally by a ``FlowRouter``.
///
/// Each ``Presented`` carries a unique ``id`` so SwiftUI can correctly animate
/// transitions between back-to-back presentations of the same ``Route``.
public struct Presented<R: Route>: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let route: R
    public let style: PresentationStyle

    public init(id: UUID = UUID(), route: R, style: PresentationStyle) {
        self.id = id
        self.route = route
        self.style = style
    }
}
