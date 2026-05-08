# Tabs

Drift does not impose a tab structure — you compose routers into a tab
coordinator that suits your app.

## Overview

Each tab gets its own ``FlowRouter``, so navigation state survives tab switches.

```swift
enum AppTab: Hashable { case home, profile }

@MainActor
final class TabCoordinator: ObservableObject {
    @Published var selected: AppTab = .home
    let home    = FlowRouter<HomeRoute>()
    let profile = FlowRouter<ProfileRoute>()
}
```

## Hosting

```swift
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

## Programmatic switching

Switch tabs from anywhere by mutating `selected`:

```swift
tabs.selected = .profile
tabs.profile.popToRoot()
tabs.profile.push(.followers(userID: "42"))
```
