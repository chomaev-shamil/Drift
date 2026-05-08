# Testing

``FlowRouter`` is a plain `@MainActor` class with no SwiftUI runtime
required, so every navigation decision is unit-testable.

## A typical ViewModel test

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

## Spying on navigation events

Inject a custom logger:

```swift
final class LoggerSpy: NavigationLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [NavigationEvent] = []
    var events: [NavigationEvent] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }
    func log(_ event: NavigationEvent) {
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }
}

@Test func track_pushIsLogged() {
    let spy = LoggerSpy()
    let router = FlowRouter<HomeRoute>(logger: spy)
    router.push(.settings)
    #expect(spy.events == [.push(route: "settings")])
}
```

## Result delivery

```swift
@Test func picker_returnsValue() async {
    let router = FlowRouter<HomeRoute>()
    async let picked: String? = router.presentForResult(.itemPicker, as: String.self)
    try? await Task.sleep(nanoseconds: 10_000_000)
    router.finish(with: "selected-id")
    #expect(await picked == "selected-id")
}
```

## What you do not need to test

- That `FlowView` renders the right SwiftUI types — those are integration tests.
- That the OS sheet animation works — Apple's job.

Test your routers and your view-models. Keep snapshot tests for the views
themselves if you want pixel-level coverage.
