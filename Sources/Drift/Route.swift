import Foundation

/// A type-safe navigation destination.
///
/// Conform an `enum` of your screens to ``Route`` to get compiler-checked
/// navigation, deeplinks, and state restoration. Cases may carry associated
/// values as long as they are themselves `Codable` and `Sendable`.
///
/// ```swift
/// enum HomeRoute: Route {
///     case detail(id: String)
///     case settings
/// }
/// ```
public protocol Route: Hashable, Codable, Sendable {}
