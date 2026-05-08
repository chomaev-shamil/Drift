import Foundation
import Testing
@testable import Drift

enum TestRoute: Route {
    case a
    case b(id: String)
    case c
}

@MainActor
struct FlowRouterTests {
    @Test func push_appendsRoute() {
        let r = FlowRouter<TestRoute>()
        r.push(.a)
        r.push(.b(id: "1"))
        #expect(r.path == [.a, .b(id: "1")])
    }

    @Test func push_debouncesDuplicates() {
        let r = FlowRouter<TestRoute>(pushDebounce: .seconds(1))
        r.push(.a)
        r.push(.a)
        #expect(r.path == [.a])
    }

    @Test func push_allowsDifferentRoutesWithinDebounce() {
        let r = FlowRouter<TestRoute>(pushDebounce: .seconds(1))
        r.push(.a)
        r.push(.c)
        #expect(r.path == [.a, .c])
    }

    @Test func popTo_keepsRouteAndCutsAbove() {
        let r = FlowRouter<TestRoute>()
        r.replaceStack([.a, .c, .b(id: "1"), .a])
        r.popTo(.c)
        #expect(r.path == [.a, .c])
    }

    @Test func popTo_missingRoute_isNoop() {
        let r = FlowRouter<TestRoute>()
        r.replaceStack([.a, .c])
        r.popTo(.b(id: "x"))
        #expect(r.path == [.a, .c])
    }

    @Test func pop_onEmptyStack_isSafe() {
        let spy = LoggerSpy()
        let r = FlowRouter<TestRoute>(logger: spy)
        r.pop()
        #expect(r.path.isEmpty)
        #expect(spy.events == [.pop(route: nil)])
    }

    @Test func dismiss_withoutPresented_isNoop() {
        let spy = LoggerSpy()
        let r = FlowRouter<TestRoute>(logger: spy)
        r.dismiss()
        #expect(r.presented == nil)
        #expect(spy.events.isEmpty)
    }

    @Test func contains_andTopAndCount() {
        let r = FlowRouter<TestRoute>()
        r.replaceStack([.a, .c])
        #expect(r.contains(.a) == true)
        #expect(r.contains(.b(id: "x")) == false)
        #expect(r.top == .c)
        #expect(r.count == 2)
    }

    @Test func presentForResult_taskCancellation_resolvesAsNil() async {
        let r = FlowRouter<TestRoute>()
        let task = Task { @MainActor in
            await r.presentForResult(.c, as: String.self)
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        let value = await task.value
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(value == nil)
        #expect(r.presented == nil)
    }

    @Test func cancelAllPending_logsDismissOfActiveModal() async {
        let spy = LoggerSpy()
        let r = FlowRouter<TestRoute>(logger: spy)
        async let _: String? = r.presentForResult(.c, as: String.self)
        try? await Task.sleep(nanoseconds: 10_000_000)
        r.cancelAllPending()
        #expect(spy.events.contains(.dismiss(route: "c")))
    }

    @Test func cancelAllPending_resolvesAllAsNil() async {
        let r = FlowRouter<TestRoute>()
        async let first: String? = r.presentForResult(.c, as: String.self)
        try? await Task.sleep(nanoseconds: 10_000_000)
        r.cancelAllPending()
        let value = await first
        #expect(value == nil)
        #expect(r.presented == nil)
    }

    @Test func pop_removesLast() {
        let r = FlowRouter<TestRoute>()
        r.push(.a); r.push(.c)
        r.pop()
        #expect(r.path == [.a])
    }

    @Test func popToRoot_clears() {
        let r = FlowRouter<TestRoute>()
        r.push(.a); r.push(.c)
        r.popToRoot()
        #expect(r.path.isEmpty)
    }

    @Test func replaceStack_overwrites() {
        let r = FlowRouter<TestRoute>()
        r.push(.a)
        r.replaceStack([.c, .b(id: "x")])
        #expect(r.path == [.c, .b(id: "x")])
    }

    @Test func present_setsSheetByDefault() {
        let r = FlowRouter<TestRoute>()
        r.present(.c)
        #expect(r.presented?.style == .sheet)
        #expect(r.presented?.route == .c)
    }

    @Test func present_fullScreen() {
        let r = FlowRouter<TestRoute>()
        r.present(.c, style: .fullScreen)
        #expect(r.presented?.style == .fullScreen)
    }

    @Test func dismiss_clearsPresented() {
        let r = FlowRouter<TestRoute>()
        r.present(.c)
        r.dismiss()
        #expect(r.presented == nil)
    }

    @Test func presentForResult_returnsValue() async {
        let r = FlowRouter<TestRoute>()
        async let result: String? = r.presentForResult(.c, as: String.self)
        try? await Task.sleep(nanoseconds: 10_000_000)
        r.finish(with: "ok")
        let value = await result
        #expect(value == "ok")
    }

    @Test func dismiss_resolvesPendingResultWithNil() async {
        let r = FlowRouter<TestRoute>()
        async let result: Int? = r.presentForResult(.c, as: Int.self)
        try? await Task.sleep(nanoseconds: 10_000_000)
        r.dismiss()
        let value = await result
        #expect(value == nil)
    }

    @Test func codable_roundTripsPath() throws {
        let r = FlowRouter<TestRoute>()
        r.replaceStack([.a, .b(id: "42"), .c])
        let data = try JSONEncoder().encode(r.path)
        let decoded = try JSONDecoder().decode([TestRoute].self, from: data)
        #expect(decoded == r.path)
    }

    @Test func presentForResult_calledTwice_resolvesFirstAsNil() async {
        let r = FlowRouter<TestRoute>()
        async let first: String? = r.presentForResult(.c, as: String.self)
        try? await Task.sleep(nanoseconds: 10_000_000)
        async let second: String? = r.presentForResult(.a, as: String.self)
        try? await Task.sleep(nanoseconds: 10_000_000)
        r.finish(with: "second")
        let firstValue = await first
        let secondValue = await second
        #expect(firstValue == nil)
        #expect(secondValue == "second")
    }

    @Test func present_overPendingResult_resolvesPendingAsNil() async {
        let r = FlowRouter<TestRoute>()
        async let pending: Int? = r.presentForResult(.c, as: Int.self)
        try? await Task.sleep(nanoseconds: 10_000_000)
        r.present(.a)
        let value = await pending
        #expect(value == nil)
    }

    @Test func logger_capturesAllEvents() {
        let spy = LoggerSpy()
        let r = FlowRouter<TestRoute>(logger: spy)
        r.push(.a)
        r.push(.c)
        r.pop()
        r.popToRoot()
        r.replaceStack([.a, .c])
        r.present(.c, style: .fullScreen)
        r.dismiss()
        #expect(spy.events == [
            .push(route: "a"),
            .push(route: "c"),
            .pop(route: "c"),
            .popToRoot,
            .replaceStack(count: 2),
            .present(route: "c", style: .fullScreen),
            .dismiss(route: "c")
        ])
    }

    @Test func finish_logsDismiss() {
        let spy = LoggerSpy()
        let r = FlowRouter<TestRoute>(logger: spy)
        r.present(.c)
        r.finish(with: "x")
        #expect(spy.events.last == .dismiss(route: "c"))
    }
}
