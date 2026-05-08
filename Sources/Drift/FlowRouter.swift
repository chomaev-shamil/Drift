import SwiftUI
import Combine

/// The single source of navigation truth for one flow.
///
/// `FlowRouter` owns a typed navigation stack (``path``) and a single
/// modal slot (``presented``). It is `@MainActor`-isolated and emits events
/// through a ``NavigationLogger``.
///
/// One router per flow (typically one per tab). Inject it into your
/// `ViewModel`s; never let a `View` call SwiftUI navigation directly.
///
/// ## Topics
///
/// ### Stack navigation
/// - ``push(_:)``
/// - ``pop()``
/// - ``popToRoot()``
/// - ``popTo(_:)``
/// - ``replaceStack(_:)``
///
/// ### Modal presentation
/// - ``present(_:style:)``
/// - ``presentForResult(_:style:as:)``
/// - ``finish(with:)``
/// - ``dismiss()``
/// - ``cancelAllPending()``
///
/// ### Inspection
/// - ``path``
/// - ``presented``
/// - ``top``
/// - ``count``
/// - ``contains(_:)``
@MainActor
public final class FlowRouter<R: Route>: ObservableObject {
    /// Current navigation stack. Mutating it directly is supported but
    /// prefer the typed methods below.
    @Published public var path: [R] = []

    /// Currently presented modal, if any.
    @Published public var presented: Presented<R>?

    private let logger: any NavigationLogger
    private let debounce: Duration
    private let clock = ContinuousClock()
    private var lastPushAt: ContinuousClock.Instant?
    private var pendingResults: [UUID: @MainActor ((any Sendable)?) -> Void] = [:]

    /// Creates a router.
    ///
    /// - Parameters:
    ///   - logger: Receives every navigation action. Defaults to no-op.
    ///   - pushDebounce: Coalesces identical pushes that arrive within this
    ///     window. Guards against double-tapped `NavigationLink`s. Default 50 ms.
    public init(
        logger: any NavigationLogger = NoopNavigationLogger(),
        pushDebounce: Duration = .milliseconds(50)
    ) {
        self.logger = logger
        self.debounce = pushDebounce
    }

    /// Number of routes in the stack.
    public var count: Int { path.count }

    /// Top of the stack, if any.
    public var top: R? { path.last }

    /// Whether `route` is anywhere in the stack.
    public func contains(_ route: R) -> Bool { path.contains(route) }

    /// Pushes a route. A second identical push within `pushDebounce` is dropped.
    public func push(_ route: R) {
        let now = clock.now
        if let last = lastPushAt,
           last.duration(to: now) < debounce,
           path.last == route {
            return
        }
        lastPushAt = now
        path.append(route)
        logger.log(.push(route: String(describing: route)))
    }

    /// Pops the top route. No-op on an empty stack.
    public func pop() {
        guard let last = path.popLast() else {
            logger.log(.pop(route: nil))
            return
        }
        logger.log(.pop(route: String(describing: last)))
    }

    /// Removes everything from the stack.
    public func popToRoot() {
        path.removeAll()
        logger.log(.popToRoot)
    }

    /// Pops everything above `route`, keeping `route` at the top. No-op if
    /// `route` is not in the stack.
    public func popTo(_ route: R) {
        guard let idx = path.lastIndex(of: route) else { return }
        path.removeSubrange(path.index(after: idx)..<path.endIndex)
        logger.log(.replaceStack(count: path.count))
    }

    /// Replaces the stack atomically. Useful for deeplinks and state restoration.
    public func replaceStack(_ routes: [R]) {
        path = routes
        logger.log(.replaceStack(count: routes.count))
    }

    /// Presents a route modally. If a result is pending it resolves to `nil`.
    public func present(_ route: R, style: PresentationStyle = .sheet) {
        resolvePending(with: nil)
        presented = Presented(route: route, style: style)
        logger.log(.present(route: String(describing: route), style: style))
    }

    /// Closes the current modal. If a result was awaited it resolves to `nil`.
    public func dismiss() {
        guard let item = presented else { return }
        resolvePending(with: nil)
        presented = nil
        logger.log(.dismiss(route: String(describing: item.route)))
    }

    /// Presents a route and awaits a typed result.
    ///
    /// The presented screen calls ``finish(with:)`` to provide the value.
    /// ``dismiss()`` and a parent task cancellation both resolve the result
    /// to `nil`. Calling ``presentForResult(_:style:as:)`` again before the
    /// previous result resolves cancels the previous one.
    ///
    /// - Returns: The value passed to ``finish(with:)``, or `nil` if the
    ///   modal was dismissed without one.
    public func presentForResult<T: Sendable>(
        _ route: R,
        style: PresentationStyle = .sheet,
        as: T.Type = T.self
    ) async -> T? {
        resolvePending(with: nil)
        let item = Presented(route: route, style: style)
        presented = item
        logger.log(.present(route: String(describing: route), style: style))

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
                pendingResults[item.id] = { value in
                    cont.resume(returning: value as? T)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelPending(id: item.id)
            }
        }
    }

    private func cancelPending(id: UUID) {
        guard let cb = pendingResults.removeValue(forKey: id) else { return }
        if presented?.id == id {
            let route = presented?.route
            presented = nil
            logger.log(.dismiss(route: route.map { String(describing: $0) }))
        }
        cb(nil)
    }

    /// Closes the current modal and delivers `value` to the awaiting caller.
    public func finish<T: Sendable>(with value: T?) {
        guard let item = presented else { return }
        let cb = pendingResults.removeValue(forKey: item.id)
        presented = nil
        cb?(value)
        logger.log(.dismiss(route: String(describing: item.route)))
    }

    /// Resolves all pending results to `nil` and clears any presented modal.
    /// Call this on user sign-out or any other root-level reset.
    public func cancelAllPending() {
        let callbacks = pendingResults.values
        pendingResults.removeAll()
        if let item = presented {
            presented = nil
            logger.log(.dismiss(route: String(describing: item.route)))
        }
        for cb in callbacks { cb(nil) }
    }

    private func resolvePending(with value: (any Sendable)?) {
        guard let id = presented?.id,
              let cb = pendingResults.removeValue(forKey: id)
        else { return }
        cb(value)
    }
}
