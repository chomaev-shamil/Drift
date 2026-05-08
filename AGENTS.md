# AGENTS.md — Drift LLM context

This file is a compact, self-contained reference designed for AI coding
assistants. Drop it into your prompt context to get correct Drift code on
the first try.

## What Drift is

A typed SwiftUI coordinator for iOS 16+. One ``FlowRouter`` per flow owns
a navigation stack and a single modal slot. Views render router state;
view-models call router methods. No DI framework, no UIKit.

- Module: `import Drift`
- Min platforms: iOS 16, tvOS 16, watchOS 9, macOS 13, visionOS 1
- Swift 6 strict concurrency, all public API `Sendable`-clean

## Public API surface (full)

```swift
// MARK: Route
public protocol Route: Hashable, Codable, Sendable {}

// MARK: Presentation
public enum PresentationStyle: Sendable, Equatable {
    case sheet
    case fullScreen
}

public struct Presented<R: Route>: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let route: R
    public let style: PresentationStyle
}

// MARK: Logging
public protocol NavigationLogger: Sendable {
    func log(_ event: NavigationEvent)
}

public enum NavigationEvent: Sendable, Equatable {
    case push(route: String)
    case pop(route: String?)
    case popToRoot
    case replaceStack(count: Int)
    case present(route: String, style: PresentationStyle)
    case dismiss(route: String?)
}

public struct NoopNavigationLogger: NavigationLogger { public init() }

// MARK: Router
@MainActor
public final class FlowRouter<R: Route>: ObservableObject {
    @Published public var path: [R]
    @Published public var presented: Presented<R>?

    public init(
        logger: any NavigationLogger = NoopNavigationLogger(),
        pushDebounce: Duration = .milliseconds(50)
    )

    // Inspection
    public var count: Int
    public var top: R?
    public func contains(_ route: R) -> Bool

    // Stack
    public func push(_ route: R)
    public func pop()
    public func popToRoot()
    public func popTo(_ route: R)
    public func replaceStack(_ routes: [R])

    // Modal
    public func present(_ route: R, style: PresentationStyle = .sheet)
    public func dismiss()
    public func presentForResult<T: Sendable>(
        _ route: R,
        style: PresentationStyle = .sheet,
        as: T.Type = T.self
    ) async -> T?
    public func finish<T: Sendable>(with value: T?)
    public func cancelAllPending()
}

// MARK: View
public struct FlowView<R: Route, Root: View, Destination: View>: View {
    public init(
        router: FlowRouter<R>,
        @ViewBuilder root: @escaping () -> Root,
        @ViewBuilder destination: @escaping (R) -> Destination
    )
}

// MARK: Deeplinks
public protocol DeeplinkParsing: Sendable {
    associatedtype Output
    func parse(_ url: URL) -> Output?
}

public protocol DeeplinkHandling: AnyObject {
    associatedtype Intent
    @MainActor func handle(_ intent: Intent)
}

@MainActor
public final class DeeplinkBuffer<Intent> {
    public init()
    public func store(_ intent: Intent)
    public func consume() -> Intent?
    public var hasPending: Bool
}
```

## Invariants and guarantees

- `push` of the same route within `pushDebounce` is dropped (NavigationLink double-tap guard).
- `present` while a result is pending resolves the previous result to `nil`.
- `dismiss()` when nothing is presented is a no-op and is **not** logged.
- Sheet swipe-down calls `dismiss()` (via the `FlowView` binding), so async results always resolve.
- Task cancellation on the awaiter resolves `presentForResult` to `nil` and dismisses.
- `cancelAllPending()` resolves all awaiting results to `nil` and clears `presented`.
- `replaceStack` and `popTo` log `replaceStack(count:)`. Other methods log their own events.
- All mutation is `@MainActor`.

## Idiomatic patterns

### One flow, one route enum

```swift
enum HomeRoute: Route {
    case detail(id: String)
    case settings
}
```

### Push from a view-model

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    private let router: FlowRouter<HomeRoute>
    init(router: FlowRouter<HomeRoute>) { self.router = router }
    func openDetail(_ id: String) { router.push(.detail(id: id)) }
}
```

### Get a typed result back

```swift
let picked: String? = await router.presentForResult(.picker, as: String.self)
// In the picker screen:
router.finish(with: "id-42")
```

### Tabs

```swift
enum AppTab: Hashable { case home, profile }

@MainActor
final class TabCoordinator: ObservableObject {
    @Published var selected: AppTab = .home
    let home    = FlowRouter<HomeRoute>()
    let profile = FlowRouter<ProfileRoute>()
}
```

### Deeplinks with a buffer for unauth state

```swift
func handle(_ intent: AppIntent) {
    guard root == .main else { buffer.store(intent); return }
    apply(intent)
}

func didSignIn() {
    root = .main
    if let pending = buffer.consume() { apply(pending) }
}
```

### Sign-out cleanup

```swift
func didSignOut() {
    tabs.home.cancelAllPending()
    tabs.profile.cancelAllPending()
    tabs.home.popToRoot()
    tabs.profile.popToRoot()
    root = .auth
}
```

### Hosting a flow

```swift
FlowView(router: router) {
    HomeRootView()
} destination: { route in
    switch route {
    case .detail(let id): DetailView(id: id)
    case .settings:       SettingsView()
    }
}
```

## Common mistakes to avoid

- **Do not** call `NavigationLink(value:)` with non-`Route` types inside a `FlowView` — destinations are dispatched only for the flow's `R`.
- **Do not** put closures or non-`Codable` types into a `Route`. Restoration and tests will break.
- **Do not** share one `FlowRouter` across multiple tabs. State will collide.
- **Do not** call `present` twice in a single tick to "stack" sheets. Drift has one modal slot per router; the second call cancels the first. Use a child router for nested modals.
- **Do not** read `router.presented = nil` directly. Use `dismiss()` so any pending async result resolves.
- **Do** call `cancelAllPending()` on sign-out and on any root-level reset.

## Restoration

`path` is `[R]` where `R: Codable`. Persist with `SceneStorage`:

```swift
@SceneStorage("home.path") private var data: Data = Data()

.onChange(of: router.path) { _, new in
    data = (try? JSONEncoder().encode(new)) ?? Data()
}
.task {
    if let restored = try? JSONDecoder().decode([HomeRoute].self, from: data) {
        router.replaceStack(restored)
    }
}
```

## Testing checklist

- View-models: assert `router.path` and `router.presented` after actions.
- Logger: inject a spy conforming to `NavigationLogger` and assert `events`.
- Async: `presentForResult` + `finish(with:)` + `Task.sleep(nanoseconds:)` to let the continuation install.

## Out of scope (do not invent)

Drift is *only* a navigation coordinator. It is not:

- a DI framework,
- an alert/toast system,
- a state management library,
- an analytics SDK.

If asked for any of those, suggest the user add their own layer on top.
