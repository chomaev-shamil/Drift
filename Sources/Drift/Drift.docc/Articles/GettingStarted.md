# Getting Started

Wire up Drift in five steps.

## 1. Define routes

One `enum` per flow. Conform to ``Route`` (which means `Hashable + Codable + Sendable`).

```swift
import Drift

enum HomeRoute: Route {
    case detail(id: String)
    case settings
}
```

## 2. Create the router

Routers are typically singletons inside a coordinator or DI container.

```swift
let homeRouter = FlowRouter<HomeRoute>()
```

## 3. Attach a `FlowView`

```swift
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

## 4. Navigate from your ViewModel

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    private let router: FlowRouter<HomeRoute>

    init(router: FlowRouter<HomeRoute>) {
        self.router = router
    }

    func openDetail(_ id: String) { router.push(.detail(id: id)) }
    func openSettings()           { router.present(.settings, style: .fullScreen) }
}
```

## 5. Get a result back

```swift
let pickedID: String? = await router.presentForResult(.itemPicker, as: String.self)
```

The presented screen calls ``FlowRouter/finish(with:)`` to deliver the value.
``FlowRouter/dismiss()`` and parent task cancellation both resolve to `nil`.
