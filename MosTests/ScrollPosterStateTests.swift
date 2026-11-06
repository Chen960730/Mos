//
//  ScrollPosterStateTests.swift
//  MosTests
//
//  ScrollPoster.shift 方法测试 (Task 10)
//

import XCTest
@testable import Mos_Debug

final class ScrollPosterStateTests: XCTestCase {

    var sut: ScrollPoster!

    override func setUp() {
        super.setUp()
        sut = ScrollPoster()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - shift: shifting = false (默认)

    func testShift_whenNotShifting_passThrough() {
        // 默认 shifting = false
        let input = (y: 5.0, x: 3.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, 5.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 3.0, accuracy: 1e-10)
    }

    func testShift_whenNotShifting_zeroValues() {
        let input = (y: 0.0, x: 0.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 0.0, accuracy: 1e-10)
    }

    func testShift_whenNotShifting_negativeValues() {
        let input = (y: -10.0, x: -7.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, -10.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, -7.0, accuracy: 1e-10)
    }

    // MARK: - shift: shifting = true, Y有值X无值 -> 交换到X

    func testShift_whenShifting_yHasValue_xIsZero_swapsToX() {
        sut.updateShifting(enable: true)
        let input = (y: 10.0, x: 0.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10, "Y should become X's original value (0)")
        XCTAssertEqual(result.x, 10.0, accuracy: 1e-10, "X should receive Y's original value")
    }

    func testShift_whenShifting_negativeY_xIsZero_swapsToX() {
        sut.updateShifting(enable: true)
        let input = (y: -8.0, x: 0.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, -8.0, accuracy: 1e-10)
    }

    // MARK: - shift: shifting = true, X已有值 (如 MX Master 横向) -> 直接传递

    func testShift_whenShifting_bothAxesHaveValues_passThrough() {
        sut.updateShifting(enable: true)
        let input = (y: 5.0, x: 3.0)
        let result = sut.shift(with: input)
        // 当 y != 0 且 x != 0 时, 不交换 (某些鼠标已经显式转换方向)
        XCTAssertEqual(result.y, 5.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 3.0, accuracy: 1e-10)
    }

    func testShift_whenShifting_onlyXHasValue_passThrough() {
        sut.updateShifting(enable: true)
        let input = (y: 0.0, x: 7.0)
        let result = sut.shift(with: input)
        // y == 0, 不符合 y != 0 && x == 0 条件, 直接传递
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 7.0, accuracy: 1e-10)
    }

    func testShift_whenShifting_bothZero_passThrough() {
        sut.updateShifting(enable: true)
        let input = (y: 0.0, x: 0.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 0.0, accuracy: 1e-10)
    }

    // MARK: - updateShifting: 切换

    func testUpdateShifting_togglesShiftBehavior() {
        // 初始: 不 shift
        let input = (y: 10.0, x: 0.0)
        var result = sut.shift(with: input)
        XCTAssertEqual(result.y, 10.0, accuracy: 1e-10)

        // 启用 shift
        sut.updateShifting(enable: true)
        result = sut.shift(with: input)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 10.0, accuracy: 1e-10)

        // 禁用 shift
        sut.updateShifting(enable: false)
        result = sut.shift(with: input)
        XCTAssertEqual(result.y, 10.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 0.0, accuracy: 1e-10)
    }

    // MARK: - 边界值

    func testShift_whenShifting_verySmallY_swapsToX() {
        sut.updateShifting(enable: true)
        let input = (y: 0.001, x: 0.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 0.001, accuracy: 1e-10)
    }

    func testShift_whenShifting_largeValues() {
        sut.updateShifting(enable: true)
        let input = (y: 10000.0, x: 0.0)
        let result = sut.shift(with: input)
        XCTAssertEqual(result.y, 0.0, accuracy: 1e-10)
        XCTAssertEqual(result.x, 10000.0, accuracy: 1e-10)
    }

    // Inspect real CGEvents produced by ScrollPoster, without posting to an app
    // or starting a global event tap / CVDisplayLink.
    private func withPosterFrames(
        chrome: Bool = true, simulateTrackpad: Bool = false,
        _ body: (ScrollPoster, ScrollDispatchContext, () -> [(CGEvent, pid_t)]) throws -> Void
    ) rethrows {
        let originalSimTrackpad = Options.shared.scroll.smoothSimTrackpad
        let originalApplication = ScrollCore.shared.application
        Options.shared.scroll.smoothSimTrackpad = simulateTrackpad
        ScrollCore.shared.application = nil
        ScrollPhase.shared.reset()
        let context = ScrollDispatchContext()
        var frames: [(CGEvent, pid_t)] = []
        context.postEventForTests = { frames.append(($0, $1)) }
        let poster = ScrollPoster(dispatchContext: context, isChromeTarget: { _ in chrome })
        defer {
            context.flushForTests()
            poster.reset()
            Options.shared.scroll.smoothSimTrackpad = originalSimTrackpad
            ScrollCore.shared.application = originalApplication
        }
        try body(poster, context, { context.flushForTests(); return frames })
    }

    private func wheelEvent(pid: Int64 = 42) throws -> CGEvent {
        let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .line,
                                         wheelCount: 2, wheel1: -3, wheel2: 2, wheel3: 0))
        event.setIntegerValueField(.eventTargetUnixProcessID, value: pid)
        event.timestamp = 1
        return event
    }

    func testChromeFramesHaveBalancedPhasesAndZeroDeltaEnd() throws {
        try withPosterFrames { poster, context, frames in
            let event = try wheelEvent()
            XCTAssertTrue(poster.update(event: event, duration: 0.1, y: -40, x: 0, speed: 1))
            XCTAssertTrue(frames().isEmpty, "an internal zero-delta transition must not start the Chrome gesture")
            XCTAssertTrue(poster.postFrameForTests(y: -8, x: 0))
            XCTAssertTrue(poster.postFrameForTests(y: -4, x: 0))
            XCTAssertFalse(poster.postFrameForTests(y: 0, x: 0))
            context.flushForTests()
            poster.stop()
            let output = frames().map { $0.0 }
            XCTAssertEqual(output.map { $0.getIntegerValueField(.scrollWheelEventScrollPhase) }, [1, 2, 4])
            XCTAssertEqual(output.map { $0.getIntegerValueField(.scrollWheelEventMomentumPhase) }, [0, 0, 0])
            XCTAssertEqual(output.map { $0.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) }, [-8, -4, 0])
            let end = try XCTUnwrap(output.last)
            for field: CGEventField in [.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2,
                                       .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2,
                                       .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2] {
                XCTAssertEqual(end.getDoubleValueField(field), 0)
            }
            XCTAssertTrue(output.allSatisfy { $0.timestamp > event.timestamp })
        }
    }

    func testChromeNewStrokeAfterPauseEndsOldGestureBeforeNewBegin() throws {
        try withPosterFrames { poster, _, frames in
            let first = try wheelEvent()
            first.location = CGPoint(x: 10, y: 20)
            poster.update(event: first, duration: 0.1, y: -40, x: 0, speed: 1)
            poster.postFrameForTests(y: -8, x: 0)
            // Exceed the real stroke separation threshold, without starting a timer.
            Thread.sleep(forTimeInterval: 0.46)
            let next = try wheelEvent()
            next.location = CGPoint(x: 30, y: 40)
            poster.update(event: next, duration: 0.1, y: -40, x: 0, speed: 1)
            poster.postFrameForTests(y: -8, x: 0)
            let output = frames().map { $0.0 }
            XCTAssertEqual(output.map { $0.getIntegerValueField(.scrollWheelEventScrollPhase) }, [1, 4, 1])
            XCTAssertEqual(output[1].location, first.location, "end belongs to the old scroll target")
            XCTAssertEqual(output[2].location, next.location)
        }
    }

    func testChromeTargetChangeClosesPreviousTargetBeforeCapturingNext() throws {
        try withPosterFrames { poster, _, frames in
            poster.update(event: try wheelEvent(pid: 42), duration: 0.1, y: -40, x: 0, speed: 1)
            poster.postFrameForTests(y: -8, x: 0)
            poster.update(event: try wheelEvent(pid: 43), duration: 0.1, y: -40, x: 0, speed: 1)
            poster.postFrameForTests(y: -8, x: 0)
            let output = frames()
            XCTAssertEqual(output.map { $0.1 }, [42, 42, 43])
            XCTAssertEqual(output.map { $0.0.getIntegerValueField(.scrollWheelEventScrollPhase) }, [1, 4, 1])
        }
    }

    func testChromeHorizontalStrokeRestartsAfterStop() throws {
        try withPosterFrames { poster, context, frames in
            let event = try wheelEvent()
            poster.update(event: event, duration: 0.1, y: 0, x: 40, speed: 1)
            poster.postFrameForTests(y: 0, x: 8)
            context.flushForTests()
            poster.stop()
            poster.update(event: event, duration: 0.1, y: 0, x: 40, speed: 1)
            poster.postFrameForTests(y: 0, x: 8)
            XCTAssertEqual(frames().map { $0.0.getIntegerValueField(.scrollWheelEventScrollPhase) }, [1, 4, 1])
        }
    }

    func testMissingTargetIsRejectedWithoutGeneratingFrames() throws {
        try withPosterFrames { poster, _, frames in
            XCTAssertFalse(poster.update(event: try wheelEvent(pid: 0), duration: 0.1, y: -40, x: 0, speed: 1))
            XCTAssertTrue(frames().isEmpty)
        }
    }

    func testNonChromeKeepsPhaseLessWheelFrames() throws {
        try withPosterFrames(chrome: false) { poster, _, frames in
            poster.update(event: try wheelEvent(), duration: 0.1, y: -40, x: 0, speed: 1)
            poster.postFrameForTests(y: -8, x: 0)
            XCTAssertTrue(frames().allSatisfy { $0.0.getIntegerValueField(.scrollWheelEventScrollPhase) == 0 })
        }
    }

    func testExplicitTrackpadSimulationKeepsItsOwnPhases() throws {
        try withPosterFrames(simulateTrackpad: true) { poster, _, frames in
            poster.update(event: try wheelEvent(), duration: 0.1, y: -40, x: 0, speed: 1)
            ScrollPhase.shared.apply(phase: .MomentumBegin)
            poster.postFrameForTests(y: -8, x: 0)
            let output = try XCTUnwrap(frames().last?.0)
            XCTAssertEqual(output.getIntegerValueField(.scrollWheelEventScrollPhase), 0)
            XCTAssertEqual(output.getIntegerValueField(.scrollWheelEventMomentumPhase), 1)
        }
    }
}
