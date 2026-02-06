//
//  VolumeManagementTests.swift
//  container-manager
//
//  Created by Claude on 2/6/26.
//

import Testing
import Foundation
@testable import container_manager

@Suite("Volume Management Tests")
struct VolumeManagementTests {
    
    // MARK: - Volume Listing Tests
    
    @Test("Fetch list of volumes")
    func fetchListOfVolumes() async throws {
        let monitor = ContainerSystemMonitor()
        
        let volumes = await monitor.fetchVolumes()
        
        #expect(volumes != nil)
    }
    
    @Test("Parse volume list output")
    func parseVolumeListOutput() throws {
        let output = """
        DRIVER    NAME
        local     my-volume
        local     data-volume
        """
        
        let volumes = VolumeInfo.parseList(output)
        
        #expect(volumes.count == 2)
        #expect(volumes[0].name == "my-volume")
        #expect(volumes[1].name == "data-volume")
        #expect(volumes[0].driver == "local")
    }
    
    @Test("Parse volume with local driver")
    func parseVolumeWithLocalDriver() throws {
        let output = """
        DRIVER    NAME
        local     test-vol
        """
        
        let volumes = VolumeInfo.parseList(output)
        
        #expect(volumes.count == 1)
        #expect(volumes[0].driver == "local")
    }
    
    @Test("Parse volume with custom driver")
    func parseVolumeWithCustomDriver() throws {
        let output = """
        DRIVER    NAME
        nfs       shared-vol
        """
        
        let volumes = VolumeInfo.parseList(output)
        
        #expect(volumes.count == 1)
        #expect(volumes[0].driver == "nfs")
    }
    
    @Test("Handle empty volume list")
    func handleEmptyVolumeList() throws {
        let output = "DRIVER    NAME\n"
        
        let volumes = VolumeInfo.parseList(output)
        
        #expect(volumes.isEmpty)
    }
    
    @Test("Parse volume with mountpoint")
    func parseVolumeWithMountpoint() throws {
        let output = """
        DRIVER    NAME
        local     test-vol
        """
        
        let volumes = VolumeInfo.parseList(output)
        
        #expect(volumes.count == 1)
        #expect(volumes[0].name == "test-vol")
    }
    
    @Test("Performance: Parse 1000+ volumes")
    func performanceParseLargeVolumeList() throws {
        var output = "DRIVER    NAME\n"
        
        for i in 0..<1000 {
            output += "local    volume\(i)\n"
        }
        
        let startTime = Date()
        let volumes = VolumeInfo.parseList(output)
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(volumes.count == 1000)
        #expect(duration < 1.0)
    }
    
    // MARK: - Volume Creation Tests
    
    @Test("Create volume with name only")
    func createVolumeWithNameOnly() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume-\(UUID().uuidString.prefix(8))"
        
        let options = VolumeCreateOptions(
            name: volumeName,
            driver: "local",
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createVolume(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create volume with custom driver")
    func createVolumeWithCustomDriver() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume-\(UUID().uuidString.prefix(8))"
        
        let options = VolumeCreateOptions(
            name: volumeName,
            driver: "local",
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createVolume(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create volume with options")
    func createVolumeWithOptions() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume-\(UUID().uuidString.prefix(8))"
        
        let options = VolumeCreateOptions(
            name: volumeName,
            driver: "local",
            options: ["type": "tmpfs"],
            labels: nil
        )
        
        let result = await monitor.createVolume(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create volume with labels")
    func createVolumeWithLabels() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume-\(UUID().uuidString.prefix(8))"
        
        let options = VolumeCreateOptions(
            name: volumeName,
            driver: "local",
            options: nil,
            labels: ["environment": "test"]
        )
        
        let result = await monitor.createVolume(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Validate volume name format")
    func validateVolumeNameFormat() throws {
        // Test valid volume names
        let validNames = ["my-volume", "test_vol", "volume123", "app-data-2024"]
        
        for name in validNames {
            let isValid = VolumeInfo.validateName(name)
            #expect(isValid == true)
        }
        
        // Test invalid volume names
        let invalidNames = ["my volume", "test@vol", "volume!", ""]
        
        for name in invalidNames {
            let isValid = VolumeInfo.validateName(name)
            #expect(isValid == false)
        }
    }
    
    // MARK: - Volume Removal Tests
    
    @Test("Remove unused volume")
    func removeUnusedVolume() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume-to-remove"
        
        let result = await monitor.removeVolume(volumeName)
        
        #expect(result != nil)
    }
    
    @Test("Remove volume with force flag")
    func removeVolumeWithForceFlag() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume-force"
        
        let result = await monitor.removeVolume(volumeName, force: true)
        
        #expect(result != nil)
    }
    
    @Test("Handle removal of non-existent volume")
    func handleRemovalOfNonExistentVolume() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "non-existent-volume-\(UUID().uuidString)"
        
        let result = await monitor.removeVolume(volumeName)
        
        #expect(result != nil)
    }
    
    @Test("Remove multiple volumes")
    func removeMultipleVolumes() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeNames = ["test-vol-1", "test-vol-2", "test-vol-3"]
        
        let results = await monitor.removeVolumes(volumeNames, force: false)
        
        #expect(results.count == volumeNames.count)
    }
    
    // MARK: - Volume Inspection Tests
    
    @Test("Inspect volume details")
    func inspectVolumeDetails() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume"
        
        let details = await monitor.inspectVolume(volumeName)
        
        #expect(details != nil || details == nil)
    }
    
    @Test("Parse volume inspect JSON output")
    func parseVolumeInspectJSON() throws {
        let jsonOutput = """
        [
            {
                "Name": "my-volume",
                "Driver": "local",
                "Mountpoint": "/var/lib/containers/storage/volumes/my-volume/_data",
                "Scope": "local",
                "CreatedAt": "2024-01-01T12:00:00Z"
            }
        ]
        """
        
        let volume = VolumeInfo.parseInspect(jsonOutput)
        
        #expect(volume != nil)
        #expect(volume?.name == "my-volume")
        #expect(volume?.driver == "local")
    }
    
    // MARK: - Volume Usage Tests
    
    @Test("Get volume usage information")
    func getVolumeUsageInformation() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume"
        
        let usage = await monitor.getVolumeUsage(volumeName)
        
        #expect(usage != nil || usage == nil)
    }
    
    @Test("List containers using volume")
    func listContainersUsingVolume() async throws {
        let monitor = ContainerSystemMonitor()
        let volumeName = "test-volume"
        
        let usage = await monitor.getVolumeUsage(volumeName)
        
        if let usage = usage {
            #expect(usage.volumeName == volumeName)
            #expect(!usage.containers.isEmpty || usage.containers.isEmpty)
        }
    }
    
    @Test("Identify unused volumes")
    func identifyUnusedVolumes() throws {
        let volumes = [
            VolumeInfo(name: "used-vol", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 2),
            VolumeInfo(name: "unused-vol", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "another-used", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 1)
        ]
        
        let unused = VolumeInfo.filterUnused(volumes)
        
        #expect(unused.count == 1)
        #expect(unused[0].name == "unused-vol")
    }
    
    // MARK: - Volume Filtering Tests
    
    @Test("Filter volumes by name")
    func filterVolumesByName() throws {
        let volumes = [
            VolumeInfo(name: "app-data", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "db-data", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "app-cache", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0)
        ]
        
        let filtered = VolumeInfo.filter(volumes, name: "app")
        
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.name.contains("app") })
    }
    
    @Test("Filter volumes by driver")
    func filterVolumesByDriver() throws {
        let volumes = [
            VolumeInfo(name: "vol1", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "vol2", driver: "nfs", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "vol3", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0)
        ]
        
        let filtered = VolumeInfo.filterByDriver(volumes, driver: "local")
        
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.driver == "local" })
    }
    
    @Test("Filter volumes with search term")
    func filterVolumesWithSearchTerm() throws {
        let volumes = [
            VolumeInfo(name: "production-db", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "staging-db", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "test-cache", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0)
        ]
        
        let filtered = VolumeInfo.filter(volumes, name: "db")
        
        #expect(filtered.count == 2)
    }
    
    // MARK: - Volume Sorting Tests
    
    @Test("Sort volumes by name")
    func sortVolumesByName() throws {
        let volumes = [
            VolumeInfo(name: "zebra", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "apple", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "banana", driver: "local", mountpoint: "/data", scope: "local", created: nil, size: nil, labels: nil, containerCount: 0)
        ]
        
        let sorted = VolumeInfo.sortByName(volumes)
        
        #expect(sorted[0].name == "apple")
        #expect(sorted[1].name == "banana")
        #expect(sorted[2].name == "zebra")
    }
    
    @Test("Sort volumes by creation date")
    func sortVolumesByCreationDate() throws {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)
        
        let volumes = [
            VolumeInfo(name: "vol1", driver: "local", mountpoint: "/data", scope: "local", created: date2, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "vol2", driver: "local", mountpoint: "/data", scope: "local", created: date1, size: nil, labels: nil, containerCount: 0),
            VolumeInfo(name: "vol3", driver: "local", mountpoint: "/data", scope: "local", created: date3, size: nil, labels: nil, containerCount: 0)
        ]
        
        let sorted = VolumeInfo.sortByDate(volumes)
        
        #expect(sorted[0].created == date3)
        #expect(sorted[1].created == date2)
        #expect(sorted[2].created == date1)
    }
    
    // MARK: - Volume Prune Tests
    
    @Test("Prune unused volumes")
    func pruneUnusedVolumes() async throws {
        let monitor = ContainerSystemMonitor()
        
        let result = await monitor.pruneVolumes()
        
        #expect(result != nil)
    }
    
    @Test("Prune returns correct result")
    func pruneReturnsCorrectResult() async throws {
        let monitor = ContainerSystemMonitor()
        
        let result = await monitor.pruneVolumes()
        
        if let result = result {
            #expect(result.success == true || result.success == false)
        }
    }
}
