# Authentication

Two patterns: a root-level switch (auth replaces main entirely) and a
modal sheet (auth appears over main when something requires it).

## Root switch

The `AppCoordinator` toggles between ``Root`` cases and rebuilds the
hierarchy. This guarantees nothing from the previous session leaks into
the next.

```swift
@MainActor
final class AppCoordinator: ObservableObject {
    enum Root: Equatable { case launching, auth, main }

    @Published var root: Root = .launching
    @Published var authModal: AuthRoute?

    let tabs: TabCoordinator
    private let auth: AuthServicing

    func start() { root = auth.isAuthorized ? .main : .auth }

    func didSignIn() {
        root = .main
    }

    func didSignOut() {
        tabs.home.cancelAllPending()
        tabs.profile.cancelAllPending()
        tabs.home.popToRoot()
        tabs.profile.popToRoot()
        root = .auth
    }
}
```

```swift
struct RootView: View {
    @ObservedObject var app: AppCoordinator

    var body: some View {
        Group {
            switch app.root {
            case .launching: ProgressView()
            case .auth:      AuthFlow()
            case .main:      MainTabsView(tabs: app.tabs)
            }
        }
        .sheet(item: $app.authModal) { route in
            AuthFlow(initial: route)
        }
        .task { app.start() }
    }
}
```

## Modal auth

When a feature inside the main flow needs a logged-in user, show auth as
a sheet without unmounting the rest:

```swift
@MainActor
final class FavouritesViewModel: ObservableObject {
    private let app: AppCoordinator
    private let auth: AuthServicing

    func toggleFavourite(_ id: String) {
        guard auth.isAuthorized else {
            app.authModal = .signIn
            return
        }
        // ...
    }
}
```

> Important: When you sign the user out, call ``FlowRouter/cancelAllPending()``
> on every router so any awaiting `presentForResult` resolves to `nil`.
