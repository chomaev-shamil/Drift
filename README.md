# Drift

[![CI](https://github.com/chomaev-shamil/Drift/actions/workflows/ci.yml/badge.svg)](https://github.com/chomaev-shamil/Drift/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%20%7C%20macOS%2013%20%7C%20tvOS%2016%20%7C%20watchOS%209%20%7C%20visionOS%201-blue.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A small, testable SwiftUI coordinator for iOS 16+.

```swift
let router = FlowRouter<HomeRoute>()
router.push(.detail(id: "42"))
let picked: String? = await router.presentForResult(.picker, as: String.self)
```

## Features

- **Type-safe routes** — `enum: Route` is checked at compile time.
- **One source of truth** — `FlowRouter` owns the stack and the modal slot.
- **Async result delivery** — `presentForResult` returns a typed value, with proper task cancellation.
- **Tabs and deeplinks** — compose routers into your tab coordinator; buffer deeplinks across auth.
- **Swift 6 strict concurrency** — no `@unchecked` escapes in production code.
- **Zero dependencies** — no Combine extensions, no UIKit, no DI framework.
- **DocC documentation** — built into Xcode, plus dedicated `AGENTS.md` for AI assistants.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/chomaev-shamil/Drift.git", from: "0.1.0")
]
```

Or in Xcode: *File → Add Package Dependencies* → `https://github.com/chomaev-shamil/Drift.git`.

## Quick start

```swift
import Drift

enum HomeRoute: Route {
    case detail(id: String)
    case settings
}

let homeRouter = FlowRouter<HomeRoute>()

struct HomeFlow: View {
    @ObservedObject var router: FlowRouter<HomeRoute>

    var body: some View {
        FlowView(router: router) {
            HomeRootView(router: router)
        } destination: { route in
            switch route {
            case .detail(let id): DetailView(id: id)
            case .settings:       SettingsView()
            }
        }
    }
}
```

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    private let router: FlowRouter<HomeRoute>
    init(router: FlowRouter<HomeRoute>) { self.router = router }

    func openDetail(_ id: String) { router.push(.detail(id: id)) }
    func openSettings()           { router.present(.settings, style: .fullScreen) }
}
```

## Async result delivery

```swift
let pickedID: String? = await router.presentForResult(.itemPicker, as: String.self)
// Inside the picker screen:
router.finish(with: "selected-42")
```

`dismiss()` and parent task cancellation both resolve to `nil`.

## Tabs

```swift
enum AppTab: Hashable { case home, profile }

@MainActor
final class TabCoordinator: ObservableObject {
    @Published var selected: AppTab = .home
    let home    = FlowRouter<HomeRoute>()
    let profile = FlowRouter<ProfileRoute>()
}

struct MainTabsView: View {
    @ObservedObject var tabs: TabCoordinator

    var body: some View {
        TabView(selection: $tabs.selected) {
            HomeFlow(router: tabs.home)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            ProfileFlow(router: tabs.profile)
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(AppTab.profile)
        }
    }
}
```

## Deeplinks

```swift
enum AppIntent: Equatable {
    case home(HomeRoute)
    case profile(ProfileRoute)
}

struct AppDeeplinkParser: DeeplinkParsing {
    func parse(_ url: URL) -> AppIntent? {
        guard url.scheme == "myapp" else { return nil }
        switch (url.host, url.pathComponents.dropFirst().first) {
        case ("home", let id?):   return .home(.detail(id: id))
        case ("profile", "edit"): return .profile(.edit)
        default:                  return nil
        }
    }
}
```

Buffer deeplinks that arrive before the user is authenticated:

```swift
@MainActor
final class AppCoordinator: ObservableObject {
    enum Root: Equatable { case launching, auth, main }

    @Published var root: Root = .launching
    let tabs: TabCoordinator
    let buffer = DeeplinkBuffer<AppIntent>()

    func handle(_ intent: AppIntent) {
        guard root == .main else { buffer.store(intent); return }
        apply(intent)
    }

    func didSignIn() {
        root = .main
        if let pending = buffer.consume() { apply(pending) }
    }

    private func apply(_ intent: AppIntent) {
        switch intent {
        case .home(let r):
            tabs.selected = .home
            tabs.home.popToRoot()
            tabs.home.push(r)
        case .profile(let r):
            tabs.selected = .profile
            tabs.profile.popToRoot()
            tabs.profile.push(r)
        }
    }
}
```

```swift
RootView()
    .onOpenURL { url in
        if let intent = parser.parse(url) { app.handle(intent) }
    }
```

## Authentication

Two patterns:

- **Root switch** — `app.root` toggles between `.auth` and `.main`, fully unmounting the previous tree.
- **Modal sheet** — `app.authModal = .signIn` shows auth over the main flow without unmounting.

On sign-out, call `cancelAllPending()` on every router so any awaiting `presentForResult` resolves to `nil`.

## Logging

```swift
struct ConsoleLogger: NavigationLogger {
    func log(_ event: NavigationEvent) { print("[NAV]", event) }
}

let router = FlowRouter<HomeRoute>(logger: ConsoleLogger())
```

## State restoration

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

## Testing

```swift
import Testing
@testable import MyApp
import Drift

@MainActor
struct HomeViewModelTests {
    @Test func openDetail_pushesRoute() {
        let router = FlowRouter<HomeRoute>()
        let vm = HomeViewModel(router: router)
        vm.openDetail("42")
        #expect(router.path == [.detail(id: "42")])
    }
}
```

Drift itself ships with 26 tests — run `swift test`.

## Documentation

- **For humans** — DocC (open the package in Xcode → *Product → Build Documentation*).
- **For AI assistants** — [`AGENTS.md`](AGENTS.md) is a self-contained reference designed to drop into an LLM context; [`llms.txt`](llms.txt) follows the emerging discovery convention.

## API cheatsheet

| Method                                  | Purpose                                                 |
| --------------------------------------- | ------------------------------------------------------- |
| `push(_:)`                              | Push to the stack, with debounce                        |
| `pop()`, `popToRoot()`                  | Pop one or all                                          |
| `popTo(_:)`                             | Keep the route at top, remove everything above          |
| `replaceStack(_:)`                      | Replace atomically (deeplinks, restoration)             |
| `present(_:style:)`                     | Sheet or fullScreen                                     |
| `dismiss()`                             | Close modal; resolves pending result to `nil`           |
| `presentForResult(_:style:as:)`         | `async` presentation, returns `T?`                      |
| `finish(with:)`                         | Close modal with a result                               |
| `cancelAllPending()`                    | Resolve every pending result and clear modal            |
| `top`, `count`, `contains(_:)`          | Inspection                                              |

## Contributing

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Drift uses
[Conventional Commits](https://www.conventionalcommits.org/), Swift Testing,
and Swift 6 strict concurrency for all new code.

## License

MIT — see [LICENSE](LICENSE).
