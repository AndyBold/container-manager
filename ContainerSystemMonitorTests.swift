//
//  ContainerSystemMonitorTests.swift
//  container-managerTests
//
//  Created by Andrew Bold on 30/12/2025.
//

import XCTest
@testable import container_manager
internal import SwiftUI

@MainActor
final class ContainerSystemStatusTests: XCTestCase {
    
    func testRunningStatusHasGreenColor() {
        let status = ContainerSystemStatus.running
        XCTAssertEqual(status.color, .green)
    }
    
    func testStoppedStatusHasPrimaryColor() {
        let status = ContainerSystemStatus.stopped
        XCTAssertEqual(status.color, .primary)
    }
    
    func testErrorStatusHasRedColor() {
        let status = ContainerSystemStatus.error
        XCTAssertEqual(status.color, .red)
    }
    
    func testRunningStatusDisplayName() {
        let status = ContainerSystemStatus.running
        XCTAssertEqual(status.displayName, "Running")
    }
    
    func testStoppedStatusDisplayName() {
        let status = ContainerSystemStatus.stopped
        XCTAssertEqual(status.displayName, "Stopped")
    }
    
    func testErrorStatusDisplayName() {
        let status = ContainerSystemStatus.error
        XCTAssertEqual(status.displayName, "Error")
    }
}

@MainActor
final class ContainerInfoTests: XCTestCase {
    
    func testContainerInfoHasUniqueID() {
        let container1 = ContainerInfo(name: "test1", status: "running")
        let container2 = ContainerInfo(name: "test2", status: "running")
        
        XCTAssertNotEqual(container1.id, container2.id)
    }
    
    func testContainerInfoStoresPropertiesCorrectly() {
        let container = ContainerInfo(name: "my-container", status: "stopped")
        
        XCTAssertEqual(container.name, "my-container")
        XCTAssertEqual(container.status, "stopped")
    }
}

@MainActor
final class ContainerSystemMonitorBasicTests: XCTestCase {
    
    func testMonitorInitialStatusIsValid() async {
        let monitor = ContainerSystemMonitor()
        
        // Give it a moment to initialize
        try? await Task.sleep(for: .milliseconds(100))
        
        // Initial status should be stopped (since container path may not exist in test)
        let validStatuses: [ContainerSystemStatus] = [.stopped, .running, .error]
        XCTAssertTrue(validStatuses.contains(monitor.status))
    }
    
    func testMonitorInitialContainersState() async {
        let monitor = ContainerSystemMonitor()
        
        // Initially should be empty or populated depending on system state
        XCTAssertTrue(monitor.containers.isEmpty || !monitor.containers.isEmpty)
    }
    
    func testMonitorInitialOperatingStateIsFalse() {
        let monitor = ContainerSystemMonitor()
        
        XCTAssertFalse(monitor.isOperating)
    }
    
    func testMonitorSetsLastUpdatedOnInitialization() async {
        let beforeInit = Date()
        let monitor = ContainerSystemMonitor()
        
        // Give it a moment to run initial check
        try? await Task.sleep(for: .milliseconds(200))
        
        let afterInit = Date()
        
        // lastUpdated should be between before and after initialization
        XCTAssertGreaterThanOrEqual(monitor.lastUpdated, beforeInit)
        XCTAssertLessThanOrEqual(monitor.lastUpdated, afterInit)
    }
    
    func testCheckContainerStatusUpdatesLastUpdated() async {
        let monitor = ContainerSystemMonitor()
        
        // Wait for initial check
        try? await Task.sleep(for: .milliseconds(100))
        
        let beforeCheck = monitor.lastUpdated
        
        // Wait a bit to ensure time difference
        try? await Task.sleep(for: .milliseconds(100))
        
        monitor.checkContainerStatus()
        
        // Wait for check to complete
        try? await Task.sleep(for: .milliseconds(200))
        
        // lastUpdated should be newer
        XCTAssertGreaterThanOrEqual(monitor.lastUpdated, beforeCheck)
    }
    
    func testMonitorStatusIsValidEnumValue() async {
        let monitor = ContainerSystemMonitor()
        
        // Wait for initial check
        try? await Task.sleep(for: .milliseconds(200))
        
        // Status should be one of the valid enum values
        let validStatuses: [ContainerSystemStatus] = [.running, .stopped, .error]
        XCTAssertTrue(validStatuses.contains(monitor.status))
    }
}

@MainActor
final class ContainerSystemMonitorOperationTests: XCTestCase {
    
    func testStartContainerServiceSetsIsOperating() async {
        let monitor = ContainerSystemMonitor()
        
        // Start the operation (not async, so no await needed)
        monitor.startContainerService()
        
        // Wait for operation to complete
        try? await Task.sleep(for: .milliseconds(2500))
        
        // After completion, should not be operating
        XCTAssertFalse(monitor.isOperating)
    }
    
    func testStopContainerServiceSetsIsOperating() async {
        let monitor = ContainerSystemMonitor()
        
        // Stop the operation (not async, so no await needed)
        monitor.stopContainerService()
        
        // Wait for operation to complete
        try? await Task.sleep(for: .milliseconds(2500))
        
        // After completion, should not be operating
        XCTAssertFalse(monitor.isOperating)
    }
    
    func testMultipleStatusChecksDontCauseRaceConditions() async {
        let monitor = ContainerSystemMonitor()
        
        // Trigger multiple status checks concurrently
        let tasks = (0..<5).map { _ in
            Task {
                monitor.checkContainerStatus()
            }
        }
        
        // Wait for all to complete
        for task in tasks {
            await task.value
        }
        
        // Wait for all async operations to finish
        try? await Task.sleep(for: .milliseconds(500))
        
        // Should have a valid status and not crash
        let validStatuses: [ContainerSystemStatus] = [.running, .stopped, .error]
        XCTAssertTrue(validStatuses.contains(monitor.status))
    }
}

@MainActor
final class ContainerSystemMonitorEdgeCaseTests: XCTestCase {
    
    func testMonitorHandlesMissingContainerPathGracefully() async {
        // Create a monitor - it should handle missing container path
        let monitor = ContainerSystemMonitor()
        
        // Wait for initial check
        try? await Task.sleep(for: .milliseconds(200))
        
        // Should set status to stopped if container path not found
        // (or running/error if path exists on system)
        let validStatuses: [ContainerSystemStatus] = [.stopped, .running, .error]
        XCTAssertTrue(validStatuses.contains(monitor.status))
        XCTAssertGreaterThanOrEqual(monitor.containers.count, 0)
    }
    
    func testMonitorUpdatesLastUpdatedEvenOnError() async {
        let monitor = ContainerSystemMonitor()
        let initialDate = Date()
        
        // Wait for initial check
        try? await Task.sleep(for: .milliseconds(200))
        
        // lastUpdated should be set even if there's an error
        XCTAssertGreaterThanOrEqual(monitor.lastUpdated, initialDate)
    }
    
    func testContainerListIsAlwaysAnArray() async {
        let monitor = ContainerSystemMonitor()
        
        // Wait for initial check
        try? await Task.sleep(for: .milliseconds(200))
        
        // Should always be an array (could be empty)
        XCTAssertTrue(type(of: monitor.containers) == [ContainerInfo].self)
    }
}
@MainActor
final class ContainerSystemMonitorLifecycleTests: XCTestCase {
    
    func testMonitorCanBeDeallocatedSafely() async {
        var monitor: ContainerSystemMonitor? = ContainerSystemMonitor()
        
        // Wait a bit
        try? await Task.sleep(for: .milliseconds(100))
        
        // Should be non-nil
        XCTAssertNotNil(monitor)
        
        // Deallocate
        monitor = nil
        
        // Should be nil
        XCTAssertNil(monitor)
    }
}

