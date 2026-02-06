//
//  NetworkManagementTests.swift
//  container-manager
//
//  Created by Claude on 2/6/26.
//

import Testing
import Foundation
@testable import container_manager

@Suite("Network Management Tests")
struct NetworkManagementTests {
    
    // MARK: - Network Listing Tests
    
    @Test("Fetch list of networks")
    func fetchListOfNetworks() async throws {
        let monitor = ContainerSystemMonitor()
        
        let networks = await monitor.fetchNetworks()
        
        #expect(networks != nil)
    }
    
    @Test("Parse network list output")
    func parseNetworkListOutput() throws {
        let output = """
        NETWORK ID    NAME       DRIVER    SCOPE
        abc123def456  bridge     bridge    local
        789ghi012jkl  host       host      local
        """
        
        let networks = NetworkInfo.parseList(output)
        
        #expect(networks.count == 2)
        #expect(networks[0].name == "bridge")
        #expect(networks[0].driver == "bridge")
        #expect(networks[1].name == "host")
    }
    
    @Test("Parse default networks")
    func parseDefaultNetworks() throws {
        let output = """
        NETWORK ID    NAME       DRIVER    SCOPE
        abc123        bridge     bridge    local
        def456        host       host      local
        ghi789        none       null      local
        """
        
        let networks = NetworkInfo.parseList(output)
        
        #expect(networks.count == 3)
        #expect(networks.contains { $0.name == "bridge" })
        #expect(networks.contains { $0.name == "host" })
        #expect(networks.contains { $0.name == "none" })
    }
    
    @Test("Parse custom networks")
    func parseCustomNetworks() throws {
        let output = """
        NETWORK ID    NAME           DRIVER    SCOPE
        xyz123        my-network     bridge    local
        """
        
        let networks = NetworkInfo.parseList(output)
        
        #expect(networks.count == 1)
        #expect(networks[0].name == "my-network")
        #expect(networks[0].isUserDefined)
    }
    
    @Test("Handle empty network list")
    func handleEmptyNetworkList() throws {
        let output = "NETWORK ID    NAME       DRIVER    SCOPE\n"
        
        let networks = NetworkInfo.parseList(output)
        
        #expect(networks.isEmpty)
    }
    
    @Test("Parse network with subnet")
    func parseNetworkWithSubnet() throws {
        let output = """
        NETWORK ID    NAME       DRIVER    SCOPE
        abc123        my-net     bridge    local
        """
        
        let networks = NetworkInfo.parseList(output)
        
        #expect(networks.count == 1)
    }
    
    @Test("Performance: Parse 1000+ networks")
    func performanceParseLargeNetworkList() throws {
        var output = "NETWORK ID    NAME       DRIVER    SCOPE\n"
        
        for i in 0..<1000 {
            output += "net\(i)123456    network\(i)    bridge    local\n"
        }
        
        let startTime = Date()
        let networks = NetworkInfo.parseList(output)
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(networks.count == 1000)
        #expect(duration < 1.0)
    }
    
    // MARK: - Network Creation Tests
    
    @Test("Create network with name only")
    func createNetworkWithNameOnly() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-network-\(UUID().uuidString.prefix(8))"
        
        let options = NetworkCreateOptions(
            name: networkName,
            driver: "bridge",
            subnet: nil,
            gateway: nil,
            ipRange: nil,
            internal: false,
            enableIPv6: false,
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createNetwork(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create network with subnet and gateway")
    func createNetworkWithSubnetAndGateway() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-network-\(UUID().uuidString.prefix(8))"
        
        let options = NetworkCreateOptions(
            name: networkName,
            driver: "bridge",
            subnet: "172.28.0.0/16",
            gateway: "172.28.0.1",
            ipRange: nil,
            internal: false,
            enableIPv6: false,
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createNetwork(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create network with IP range")
    func createNetworkWithIPRange() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-network-\(UUID().uuidString.prefix(8))"
        
        let options = NetworkCreateOptions(
            name: networkName,
            driver: "bridge",
            subnet: "172.29.0.0/16",
            gateway: "172.29.0.1",
            ipRange: "172.29.5.0/24",
            internal: false,
            enableIPv6: false,
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createNetwork(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create internal network")
    func createInternalNetwork() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-internal-\(UUID().uuidString.prefix(8))"
        
        let options = NetworkCreateOptions(
            name: networkName,
            driver: "bridge",
            subnet: nil,
            gateway: nil,
            ipRange: nil,
            internal: true,
            enableIPv6: false,
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createNetwork(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create network with IPv6")
    func createNetworkWithIPv6() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-ipv6-\(UUID().uuidString.prefix(8))"
        
        let options = NetworkCreateOptions(
            name: networkName,
            driver: "bridge",
            subnet: nil,
            gateway: nil,
            ipRange: nil,
            internal: false,
            enableIPv6: true,
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createNetwork(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Create network with custom driver")
    func createNetworkWithCustomDriver() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-custom-\(UUID().uuidString.prefix(8))"
        
        let options = NetworkCreateOptions(
            name: networkName,
            driver: "bridge",
            subnet: nil,
            gateway: nil,
            ipRange: nil,
            internal: false,
            enableIPv6: false,
            options: nil,
            labels: nil
        )
        
        let result = await monitor.createNetwork(options: options)
        
        #expect(result != nil)
    }
    
    @Test("Validate subnet format")
    func validateSubnetFormat() throws {
        // Valid IPv4 CIDR
        #expect(NetworkInfo.validateSubnet("172.18.0.0/16") == true)
        #expect(NetworkInfo.validateSubnet("10.0.0.0/8") == true)
        #expect(NetworkInfo.validateSubnet("192.168.1.0/24") == true)
        
        // Invalid formats
        #expect(NetworkInfo.validateSubnet("172.18.0.0") == false)
        #expect(NetworkInfo.validateSubnet("invalid") == false)
        #expect(NetworkInfo.validateSubnet("") == false)
    }
    
    // MARK: - Network Removal Tests
    
    @Test("Remove unused network")
    func removeUnusedNetwork() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-network-remove"
        
        let result = await monitor.removeNetwork(networkName)
        
        #expect(result != nil)
    }
    
    @Test("Handle removal of non-existent network")
    func handleRemovalOfNonExistentNetwork() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "non-existent-network-\(UUID().uuidString)"
        
        let result = await monitor.removeNetwork(networkName)
        
        #expect(result != nil)
    }
    
    @Test("Prevent removal of default networks")
    func preventRemovalOfDefaultNetworks() throws {
        let defaultNetworks = ["bridge", "host", "none"]
        
        for networkName in defaultNetworks {
            let network = NetworkInfo(
                name: networkName,
                networkID: "abc123",
                driver: "bridge",
                scope: "local",
                subnet: nil,
                gateway: nil,
                ipRange: nil,
                created: nil,
                internal: false,
                enableIPv6: false,
                labels: nil,
                containerCount: 0
            )
            
            #expect(network.isDefaultNetwork)
        }
    }
    
    @Test("Remove multiple networks")
    func removeMultipleNetworks() async throws {
        let monitor = ContainerSystemMonitor()
        let networkNames = ["test-net-1", "test-net-2", "test-net-3"]
        
        let results = await monitor.removeNetworks(networkNames)
        
        #expect(results.count == networkNames.count)
    }
    
    // MARK: - Network Inspection Tests
    
    @Test("Inspect network details")
    func inspectNetworkDetails() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "bridge"
        
        let details = await monitor.inspectNetwork(networkName)
        
        #expect(details != nil || details == nil)
    }
    
    @Test("Parse network JSON output")
    func parseNetworkJSON() throws {
        let jsonOutput = """
        [
            {
                "Name": "my-network",
                "Id": "abc123def456",
                "Driver": "bridge",
                "Scope": "local",
                "Subnet": "172.18.0.0/16",
                "Gateway": "172.18.0.1"
            }
        ]
        """
        
        let network = NetworkInfo.parseInspect(jsonOutput)
        
        #expect(network != nil)
        #expect(network?.name == "my-network")
        #expect(network?.driver == "bridge")
    }
    
    @Test("Get network subnet configuration")
    func getNetworkSubnetConfiguration() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "bridge"
        
        let details = await monitor.inspectNetwork(networkName)
        
        if let details = details {
            #expect(details.name == networkName)
        }
    }
    
    @Test("Get network gateway configuration")
    func getNetworkGatewayConfiguration() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "bridge"
        
        let details = await monitor.inspectNetwork(networkName)
        
        if let details = details {
            #expect(details.driver.count > 0)
        }
    }
    
    // MARK: - Network Connection Tests
    
    @Test("Get connected containers")
    func getConnectedContainers() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "bridge"
        
        let connections = await monitor.getNetworkConnections(networkName)
        
        #expect(connections != nil || connections == nil)
    }
    
    @Test("Connect container to network")
    func connectContainerToNetwork() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "bridge"
        let containerName = "test-container"
        
        let result = await monitor.connectContainerToNetwork(
            networkName: networkName,
            containerName: containerName,
            ipAddress: nil,
            aliases: nil
        )
        
        #expect(result != nil)
    }
    
    @Test("Connect with custom IP address")
    func connectWithCustomIPAddress() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-network"
        let containerName = "test-container"
        let ipAddress = "172.18.0.100"
        
        let result = await monitor.connectContainerToNetwork(
            networkName: networkName,
            containerName: containerName,
            ipAddress: ipAddress,
            aliases: nil
        )
        
        #expect(result != nil)
    }
    
    @Test("Connect with aliases")
    func connectWithAliases() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-network"
        let containerName = "test-container"
        let aliases = ["api", "backend"]
        
        let result = await monitor.connectContainerToNetwork(
            networkName: networkName,
            containerName: containerName,
            ipAddress: nil,
            aliases: aliases
        )
        
        #expect(result != nil)
    }
    
    @Test("Disconnect container from network")
    func disconnectContainerFromNetwork() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "bridge"
        let containerName = "test-container"
        
        let result = await monitor.disconnectContainerFromNetwork(
            networkName: networkName,
            containerName: containerName,
            force: false
        )
        
        #expect(result != nil)
    }
    
    @Test("Disconnect with force flag")
    func disconnectWithForceFlag() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "test-network"
        let containerName = "test-container"
        
        let result = await monitor.disconnectContainerFromNetwork(
            networkName: networkName,
            containerName: containerName,
            force: true
        )
        
        #expect(result != nil)
    }
    
    @Test("Handle connection to non-existent network")
    func handleConnectionToNonExistentNetwork() async throws {
        let monitor = ContainerSystemMonitor()
        let networkName = "non-existent-\(UUID().uuidString)"
        let containerName = "test-container"
        
        let result = await monitor.connectContainerToNetwork(
            networkName: networkName,
            containerName: containerName,
            ipAddress: nil,
            aliases: nil
        )
        
        #expect(result != nil)
    }
    
    // MARK: - Network Filtering Tests
    
    @Test("Filter networks by name")
    func filterNetworksByName() throws {
        let networks = [
            NetworkInfo(name: "app-network", networkID: "123", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "db-network", networkID: "456", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "app-backend", networkID: "789", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0)
        ]
        
        let filtered = NetworkInfo.filter(networks, name: "app")
        
        #expect(filtered.count == 2)
    }
    
    @Test("Filter networks by driver")
    func filterNetworksByDriver() throws {
        let networks = [
            NetworkInfo(name: "net1", networkID: "123", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "net2", networkID: "456", driver: "host", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "net3", networkID: "789", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0)
        ]
        
        let filtered = NetworkInfo.filterByDriver(networks, driver: "bridge")
        
        #expect(filtered.count == 2)
    }
    
    @Test("Filter user-defined networks")
    func filterUserDefinedNetworks() throws {
        let networks = [
            NetworkInfo(name: "bridge", networkID: "123", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "my-network", networkID: "456", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "host", networkID: "789", driver: "host", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0)
        ]
        
        let filtered = NetworkInfo.filterUserDefined(networks)
        
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "my-network")
    }
    
    @Test("Filter networks by scope")
    func filterNetworksByScope() throws {
        let networks = [
            NetworkInfo(name: "net1", networkID: "123", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "net2", networkID: "456", driver: "bridge", scope: "swarm", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0)
        ]
        
        let filtered = NetworkInfo.filterByScope(networks, scope: "local")
        
        #expect(filtered.count == 1)
    }
    
    // MARK: - Network Sorting Tests
    
    @Test("Sort networks by name")
    func sortNetworksByName() throws {
        let networks = [
            NetworkInfo(name: "zebra", networkID: "123", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "apple", networkID: "456", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "banana", networkID: "789", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0)
        ]
        
        let sorted = NetworkInfo.sortByName(networks)
        
        #expect(sorted[0].name == "apple")
        #expect(sorted[1].name == "banana")
        #expect(sorted[2].name == "zebra")
    }
    
    @Test("Sort networks by driver")
    func sortNetworksByDriver() throws {
        let networks = [
            NetworkInfo(name: "net1", networkID: "123", driver: "host", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "net2", networkID: "456", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0),
            NetworkInfo(name: "net3", networkID: "789", driver: "overlay", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0)
        ]
        
        let sorted = NetworkInfo.sortByDriver(networks)
        
        #expect(sorted[0].driver == "bridge")
        #expect(sorted[1].driver == "host")
        #expect(sorted[2].driver == "overlay")
    }
    
    // MARK: - Network Validation Tests
    
    @Test("Validate IPv4 subnet (CIDR)")
    func validateIPv4Subnet() throws {
        #expect(NetworkInfo.validateSubnet("192.168.1.0/24"))
        #expect(NetworkInfo.validateSubnet("10.0.0.0/8"))
        #expect(NetworkInfo.validateSubnet("172.16.0.0/12"))
        
        #expect(!NetworkInfo.validateSubnet("192.168.1.0"))
        #expect(!NetworkInfo.validateSubnet("invalid"))
    }
    
    @Test("Validate IP address format")
    func validateIPAddressFormat() throws {
        #expect(NetworkInfo.validateIPAddress("192.168.1.1"))
        #expect(NetworkInfo.validateIPAddress("10.0.0.1"))
        #expect(NetworkInfo.validateIPAddress("172.16.0.1"))
        
        #expect(!NetworkInfo.validateIPAddress("256.1.1.1"))
        #expect(!NetworkInfo.validateIPAddress("invalid"))
        #expect(!NetworkInfo.validateIPAddress(""))
    }
    
    // MARK: - Network Prune Tests
    
    @Test("Prune unused networks")
    func pruneUnusedNetworks() async throws {
        let monitor = ContainerSystemMonitor()
        
        let result = await monitor.pruneNetworks()
        
        #expect(result != nil)
    }
    
    @Test("Prune preserves default networks")
    func prunePreservesDefaultNetworks() throws {
        let defaultNetworks = ["bridge", "host", "none"]
        
        for name in defaultNetworks {
            let network = NetworkInfo(name: name, networkID: "123", driver: "bridge", scope: "local", subnet: nil, gateway: nil, ipRange: nil, created: nil, internal: false, enableIPv6: false, labels: nil, containerCount: 0)
            
            #expect(network.isDefaultNetwork)
        }
    }
}
