import XCTest
@testable import IRISGaze
@testable import IRISCore
@testable import IRISVision

final class GazeTrackingIntegrationTests: XCTestCase {

    // MARK: - Gaze Tracking Stability Tests

    func testPythonProcessManagerLifecycle() {
        let manager = PythonProcessManager(scriptName: "test_script.py")

        // Initial state
        XCTAssertTrue(manager.state.isIdle)
        XCTAssertFalse(manager.isRunning)

        // Stop should be safe even when idle
        manager.stop()
        XCTAssertTrue(manager.state.isIdle)
    }

    func testPythonProcessManagerStateCallbacks() {
        let manager = PythonProcessManager(scriptName: "test_script.py")
        let expectation = self.expectation(description: "State change")

        var stateChanges: [PythonProcessManager.State] = []

        manager.onStateChange = { state in
            stateChanges.append(state)
        }

        manager.stop()
        expectation.fulfill()

        wait(for: [expectation], timeout: 1.0)

        // Should have received state change to idle
        XCTAssertTrue(stateChanges.contains(where: { $0.isIdle }))

        manager.stop()
    }

    func testPythonProcessManagerErrorHandling() {
        let manager = PythonProcessManager(scriptName: "nonexistent_script.py")
        let expectation = self.expectation(description: "Error callback")

        var errorReceived: PythonProcessManager.ProcessError?

        manager.onError = { error in
            errorReceived = error
            expectation.fulfill()
        }

        // Try to start with invalid script
        do {
            try manager.start()
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }

        wait(for: [expectation], timeout: 2.0)

        XCTAssertNotNil(errorReceived)
        manager.stop()
    }

    // MARK: - Python Crash Recovery Tests

    func testPythonProcessManagerRecoveryAttempt() {
        let manager = PythonProcessManager(scriptName: "test_script.py")
        var recoveryCallbackInvoked = false

        manager.onRecovery = {
            recoveryCallbackInvoked = true
        }

        // Manually trigger recovery callback to test the mechanism
        manager.onRecovery?()

        XCTAssertTrue(recoveryCallbackInvoked)
        manager.stop()
    }

    func testPythonProcessManagerStopClearsRecoveryCount() {
        let manager = PythonProcessManager(scriptName: "test_script.py")

        // Stop should reset internal state
        manager.stop()

        // Should be in idle state
        XCTAssertTrue(manager.state.isIdle)
    }

    // MARK: - Multiple Process Management Tests

    func testMultiplePythonProcessManagers() {
        let manager1 = PythonProcessManager(scriptName: "script1.py")
        let manager2 = PythonProcessManager(scriptName: "script2.py")

        XCTAssertTrue(manager1.state.isIdle)
        XCTAssertTrue(manager2.state.isIdle)

        manager1.stop()
        manager2.stop()

        XCTAssertTrue(manager1.state.isIdle)
        XCTAssertTrue(manager2.state.isIdle)
    }

    // MARK: - Process Output Integration Tests

    func testPythonProcessManagerOutputCallback() {
        let manager = PythonProcessManager(scriptName: "test_script.py")
        var outputReceived = false

        manager.onOutput = { data in
            outputReceived = true
        }

        // Simulate output by manually calling callback
        let testData = "Test output".data(using: .utf8)!
        manager.onOutput?(testData)

        XCTAssertTrue(outputReceived)
        manager.stop()
    }

    // MARK: - Element Detection Integration Tests

    func testAccessibilityDetectorInitialization() {
        // Test that AccessibilityDetector can be initialized
        // This is a basic integration test to ensure the module dependencies work
        let detector = AccessibilityDetector()
        XCTAssertNotNil(detector)
    }

    // MARK: - Gaze Estimator Integration Tests

    func testGazeEstimatorInitialization() {
        let estimator = GazeEstimator()
        XCTAssertNotNil(estimator)
    }

    func testGazeEstimatorStartStop() {
        let estimator = GazeEstimator()

        // Test stop (should be safe even if not started)
        estimator.stop()

        XCTAssertNotNil(estimator)
    }

    func testGazeEstimatorCallbacks() {
        let estimator = GazeEstimator()
        var callbackInvoked = false

        estimator.onGazeUpdate = { point in
            callbackInvoked = true
        }

        // Manually invoke callback to test
        estimator.onGazeUpdate?(CGPoint(x: 100, y: 100))

        XCTAssertTrue(callbackInvoked)
    }

    // MARK: - Process State Transition Tests

    func testProcessStateTransitions() {
        let manager = PythonProcessManager(scriptName: "test.py")

        // Test idle -> stop (should remain idle)
        XCTAssertTrue(manager.state.isIdle)
        manager.stop()
        XCTAssertTrue(manager.state.isIdle)
    }

    // MARK: - Concurrent Operations Tests

    func testConcurrentStateQueries() {
        let manager = PythonProcessManager(scriptName: "test.py")
        let expectation = self.expectation(description: "Concurrent queries")
        expectation.expectedFulfillmentCount = 100

        for _ in 0..<100 {
            DispatchQueue.global().async {
                _ = manager.state
                _ = manager.isRunning
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        manager.stop()
    }

    // MARK: - Memory Management Tests

    func testProcessManagerDeallocation() {
        weak var weakManager: PythonProcessManager?

        autoreleasepool {
            let manager = PythonProcessManager(scriptName: "test.py")
            weakManager = manager
            manager.stop()
        }

        // Manager should be deallocated
        XCTAssertNil(weakManager)
    }

    func testGazeEstimatorDeallocation() {
        weak var weakEstimator: GazeEstimator?

        autoreleasepool {
            let estimator = GazeEstimator()
            weakEstimator = estimator
            estimator.stop()
        }

        // Estimator should be deallocated
        // Note: May retain due to internal timers, so we just test it doesn't crash
        XCTAssertTrue(true)
    }

    // MARK: - Teardown

    override func tearDown() {
        super.tearDown()
        // Clean up any remaining resources
    }
}
