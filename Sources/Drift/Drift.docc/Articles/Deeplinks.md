# Deeplinks

Parse URLs into typed intents and apply them to the right flow — even if
the user is not yet ready to receive them.

## Define an intent

```swift
enum AppIntent: Equatable {
    case home(HomeRoute)
    case profile(ProfileRoute)
    case switchTab(AppTab)
}
```

## Implement a parser

Conform to ``DeeplinkParsing``:

```swift
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

## Apply intents in a coordinator

If the app is not ready (auth flow, onboarding), use a ``DeeplinkBuffer``:

```swift
@MainActor
final class AppCoordinator: ObservableObject {
    let tabs: TabCoordinator
    let buffer = DeeplinkBuffer<AppIntent>()
    @Published var root: Root = .auth

    func handle(_ intent: AppIntent) {
        guard root == .main else {
            buffer.store(intent)
            return
        }
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
        case .switchTab(let t):
            tabs.selected = t
        }
    }
}
```

## Wire into SwiftUI

```swift
RootView()
    .onOpenURL { url in
        if let intent = parser.parse(url) { app.handle(intent) }
    }
```

## Universal Links

The same parser handles `NSUserActivity.webpageURL`:

```swift
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    if let url = activity.webpageURL,
       let intent = parser.parse(url) {
        app.handle(intent)
    }
}
```
