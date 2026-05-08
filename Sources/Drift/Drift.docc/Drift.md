# ``Drift``

A small, testable SwiftUI coordinator for iOS 16+.

## Overview

Drift gives each flow in your app a typed navigation stack and a single
modal slot, separated cleanly from your views. ViewModels call the router;
views just render its state.

```swift
enum HomeRoute: Route {
    case detail(id: String)
    case settings
}

struct HomeFlow: View {
    @ObservedObject var router: FlowRouter<HomeRoute>

    var body: some View {
        FlowView(router: router) {
            HomeRootView()
        } destination: { route in
            switch route {
            case .detail(let id): DetailView(id: id)
            case .settings:       SettingsView()
            }
        }
    }
}
```

## Why Drift

- **Type-safe routes** — enums conforming to ``Route`` are checked at compile time.
- **One source of truth** — ``FlowRouter`` owns the stack and the modal slot.
- **Async result** — ``FlowRouter/presentForResult(_:style:as:)`` returns a
  typed value or `nil` on dismiss/cancel.
- **Swift 6 strict** — no `@unchecked` escapes in production code.
- **No dependencies** — no Combine extensions, no UIKit, no DI framework.

## Topics

### Essentials
- ``Route``
- ``FlowRouter``
- ``FlowView``

### Modal Presentation
- ``Presented``
- ``PresentationStyle``

### Logging
- ``NavigationLogger``
- ``NavigationEvent``
- ``NoopNavigationLogger``

### Deeplinks
- ``DeeplinkParsing``
- ``DeeplinkHandling``
- ``DeeplinkBuffer``

### Articles
- <doc:GettingStarted>
- <doc:Tabs>
- <doc:Deeplinks>
- <doc:AuthFlow>
- <doc:Testing>
