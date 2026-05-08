import SwiftUI

/// SwiftUI host that renders a ``FlowRouter``'s state.
///
/// Wraps `NavigationStack`, `.sheet`, and `.fullScreenCover`. You provide
/// the root view of the flow and a builder that maps each ``Route`` to a
/// view. On macOS, where `fullScreenCover` is unavailable, full-screen
/// presentations fall back to a sheet.
///
/// ```swift
/// FlowView(router: home) {
///     HomeRootView()
/// } destination: { route in
///     switch route {
///     case .detail(let id): DetailView(id: id)
///     case .settings:       SettingsView()
///     }
/// }
/// ```
public struct FlowView<R: Route, Root: View, Destination: View>: View {
    @ObservedObject private var router: FlowRouter<R>
    private let root: () -> Root
    private let destination: (R) -> Destination

    public init(
        router: FlowRouter<R>,
        @ViewBuilder root: @escaping () -> Root,
        @ViewBuilder destination: @escaping (R) -> Destination
    ) {
        self.router = router
        self.root = root
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            root()
                .navigationDestination(for: R.self) { destination($0) }
        }
        .sheet(item: sheetBinding) { item in
            destination(item.route)
        }
        .modifier(FullScreenCoverModifier(binding: fullScreenBinding, destination: destination))
    }

    private var sheetBinding: Binding<Presented<R>?> {
        Binding(
            get: { router.presented?.style == .sheet ? router.presented : nil },
            set: { newValue in if newValue == nil { router.dismiss() } }
        )
    }

    private var fullScreenBinding: Binding<Presented<R>?> {
        Binding(
            get: { router.presented?.style == .fullScreen ? router.presented : nil },
            set: { newValue in if newValue == nil { router.dismiss() } }
        )
    }
}

private struct FullScreenCoverModifier<R: Route, Destination: View>: ViewModifier {
    let binding: Binding<Presented<R>?>
    let destination: (R) -> Destination

    func body(content: Content) -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
        content.fullScreenCover(item: binding) { item in
            destination(item.route)
        }
        #else
        content.sheet(item: binding) { item in
            destination(item.route)
        }
        #endif
    }
}
