//
//  PacketTunnelProvider.swift
//  MoonbounceiOSNetworkExtension
//
//  Created by Adelita Schule on 1/11/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import NetworkExtension
import Network
import SwiftQueue
import Transport
import Replicant
import ReplicantSwift

class PacketTunnelProvider: NEPacketTunnelProvider
{
    /// Use this to create connections
    //var connectionFactory: NetworkConnectionFactory?
    var replicantConnectionFactory: ReplicantConnectionFactory?
    
    /// The tunnel connection.
    open var connection: ReplicantConnection?
    
    /// The single logical flow of packets through the tunnel.
    var tunnelConnection: ClientTunnelConnection?
    
    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((Error?) -> Void)?
    
    /// The completion handler to call when the tunnel is fully disconnected.
    var pendingStopCompletion: (() -> Void)?
    
    /// The last error that occurred on the tunnel.
    var lastError: Error?
    
    /// A Queue of Log Messages
    var logQueue = Queue<String>()
    
    /// The address of the tunnel server.
    open var remoteHost: String?
    
    /// To make sure that we don't try connecting repeatedly and unintentionally
    var connectionAttemptStatus: ConnectionAttemptStatus = .initialized
    
    // Testing Properties
    let testIPString = "192.168.1.72"
    let testPort: UInt16 = 1234
    let serverPublicKey = Data(base64Encoded: "BL7+Vd087+p/roRp6jSzIWzG3qXhk2S4aefLcYjwRtxGanWUoeoIWmMkAHfiF11vA9d6rhiSjPDL0WFGiSr/Et+wwG7gOrLf8yovmtgSJlooqa7lcMtipTxegPAYtd5yZg==")
    let chunkSize: UInt16 = 2000
    let chunkTimeout: Int = 1000

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void)
    {
        logQueue.enqueue("startTunnel called")
        
        switch connectionAttemptStatus
        {
        case .initialized:
            connectionAttemptStatus = .started
        case .started:
            logQueue.enqueue("start tunnel called when tunnel was already started.")
        case .connecting:
            connectionAttemptStatus = .started
        }

        // Save the completion handler for when the tunnel is fully established.
        pendingStartCompletion = completionHandler
        
//        guard let serverAddress: String = self.protocolConfiguration.serverAddress
//            else
//        {
//            logQueue.enqueue("Unable to get the server address.")
//            completionHandler(TunnelError.badConfiguration)
//            return
//        }
//        self.remoteHost = serverAddress
        
        self.remoteHost = testIPString
        
        
        //FIXME: Needs to be the server address not hard-coded
        let host = NWEndpoint.Host(testIPString)
        self.logQueue.enqueue("Server address: \(host.debugDescription)")

        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            logQueue.enqueue("Unable to get NWEndpoint.Port from UInt16: \(testPort).")
            return
        }
        
        //connectionFactory = NetworkConnectionFactory(host: host, port: port)
        //let toneburstConfig = ToneBurstClientConfig
        guard let publicKey = serverPublicKey
        else
        {
            logQueue.enqueue("Failed to create server public key from string.")
            return
        }
        
        guard let replicantConfig = ReplicantConfig(serverPublicKey: publicKey, chunkSize: chunkSize, chunkTimeout: chunkTimeout, toneBurst: nil)
        else
        {
            logQueue.enqueue("Failed to create replicant config for testing.")
            return
        }
        
        replicantConnectionFactory = ReplicantConnectionFactory(host: host, port: port, config: replicantConfig, logQueue: logQueue)
        logQueue.enqueue("\nConnection Factory Created.\nHost - \(host)\nPort - \(port)\n")        
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void)
    {
        logQueue.enqueue("closeTunnel Called")
        
        // Clear out any pending start completion handler.
        pendingStartCompletion?(TunnelError.internalError)
        pendingStartCompletion = nil
        
        // Close the tunnel connection.
        if let TCPConnection = connection
        {
            TCPConnection.cancel()
        }
        
        connectionAttemptStatus = .initialized
        pendingStopCompletion?()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?)
    {
        switch connectionAttemptStatus
        {
        case .initialized:
            logQueue.enqueue("handleAppMessage called before start tunnel. Doing nothing...")
        case .started:
            connectionAttemptStatus = .connecting
            setTunnelSettings(configuration: [:])
        case .connecting:
            break
        }
        
        var responseString = "Nothing to see here!"
        
        if let logMessage = self.logQueue.dequeue()
        {
            responseString = "\n*******\(logMessage)*******\n"
        }
        else
        {
            responseString = ""
        }
        
        let responseData = responseString.data(using: String.Encoding.utf8)
        
        completionHandler?(responseData)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    open func closeTunnelWithError(_ error: Error?)
    {
        logQueue.enqueue("Closing the tunnel with error: \(String(describing: error))")
        lastError = error
        pendingStartCompletion?(error)
        
        // Close the tunnel connection.
        if let TCPConnection = connection
        {
            TCPConnection.cancel()
        }
        
        tunnelConnection = nil
        connectionAttemptStatus = .initialized
    }
    
    /// Handle the event of the tunnel connection being closed.
    func tunnelDidClose()
    {
        if pendingStartCompletion != nil
        {
            // Closed while starting, call the start completion handler with the appropriate error.
            pendingStartCompletion?(lastError)
            pendingStartCompletion = nil
        }
        else if pendingStopCompletion != nil
        {
            // Closed as the result of a call to stopTunnelWithReason, call the stop completion handler.
            pendingStopCompletion?()
            pendingStopCompletion = nil
        }
        else
        {
            // Closed as the result of an error on the tunnel connection, cancel the tunnel.
            cancelTunnelWithError(lastError)
        }
    }
    
    // MARK: - ClientTunnelConnection
    
    /// Handle the event of the logical flow of packets being established through the tunnel.
    func setTunnelSettings(configuration: [NSObject: AnyObject])
    {
        logQueue.enqueue("\n🚀 tunnelConnectionDidOpen  🚀\n")
        
        // Create the virtual interface settings.
        guard let settings = createTunnelSettingsFromConfiguration(configuration)
            else
        {
            connectionAttemptStatus = .initialized
            pendingStartCompletion?(TunnelError.internalError)
            pendingStartCompletion = nil
            return
        }
        
        // Set the virtual interface settings.
        setTunnelNetworkSettings(settings, completionHandler: tunnelSettingsCompleted)
    }
    
    func tunnelSettingsCompleted(maybeError: Error?)
    {
        logQueue.enqueue("Tunnel settings updated.")
        if let error = maybeError
        {
            self.logQueue.enqueue("Failed to set the tunnel network settings: \(error)")
            connectionAttemptStatus = .initialized
            self.pendingStartCompletion?(error)
            self.pendingStartCompletion = nil
        }
        else
        {
            connectToServer()
        }
    }
    
    /// Create the tunnel network settings to be applied to the virtual interface.
    func createTunnelSettingsFromConfiguration(_ configuration: [NSObject: AnyObject]) -> NEPacketTunnelNetworkSettings?
    {
        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "166.78.129.122")
        let address = "192.168.2.1"
        let netmask = "255.255.255.0"
        
        //FIXME: tunnelAddress should be remoteHost,
        // configuration argument is ignored
        //        guard let tunnelAddress = remoteHost
        //        else
        //        {
        //            logQueue.enqueue("Unable to resolve tunnelAddress for NEPacketTunnelNetworkSettings")
        //            return nil
        //
        //        }
        //
        //        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
        newSettings.ipv4Settings = NEIPv4Settings(addresses: [address], subnetMasks: [netmask])
        newSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        newSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        newSettings.tunnelOverheadBytes = 150
        
        return newSettings
    }
    
    //MARK: - Helper Functions
    
    func connectToServer()
    {
        logQueue.enqueue("Connect to server called.")
        guard let replicantConnectionFactory = replicantConnectionFactory
            else
        {
            logQueue.enqueue("Unable to find connection factory.")
            return
        }
        
        let parameters = NWParameters.tcp
        let connectQueue = DispatchQueue(label: "connectQueue")
        
        guard let replicantConnection = replicantConnectionFactory.connect(using: parameters) as? ReplicantConnection
            else
        {
            logQueue.enqueue("🥀  Replicant Factory failed to create a connection. 🥀")
            return
        }
        
        connection = replicantConnection

        // Kick off the connection to the server
        logQueue.enqueue("Kicking off the connection to the server.")
        connection!.stateUpdateHandler = handleStateUpdate
        connection!.start(queue: connectQueue)
    }
    
    func handleStateUpdate(newState: NWConnection.State)
    {
        self.logQueue.enqueue("CURRENT STATE = \(newState))")
        
        guard let startCompletion = pendingStartCompletion
            else
        {
            logQueue.enqueue("pendingStartCompletion is nil?")
            return
        }
        
        switch newState
        {
        case .ready:
            // Start reading messages from the tunnel connection.
            self.tunnelConnection?.startHandlingPackets()
            
            // Open the logical flow of packets through the tunnel.
            guard connection != nil
            else
            {
                logQueue.enqueue("Ready state but replicant connection is nil.")
                return
            }
            
            let newConnection = ClientTunnelConnection(clientPacketFlow: self.packetFlow, replicantConnection: connection!, logQueue: logQueue)
            
            self.logQueue.enqueue("\n🚀 open() called on tunnel connection  🚀\n")
            self.tunnelConnection = newConnection
            startCompletion(nil)
            
        case .cancelled:
            self.logQueue.enqueue("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
            self.connection = nil
            self.tunnelDidClose()
            startCompletion(TunnelError.cancelled)
            
        case .failed(let error):
            self.logQueue.enqueue("\n🐒💨  Connection Failed  🐒💨\n")
            self.closeTunnelWithError(error)
            startCompletion(error)
            
        default:
            self.logQueue.enqueue("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
        }
    }
}

enum ConnectionAttemptStatus
{
    case initialized
    case started
    case connecting
}

public enum TunnelError: Error
{
    case badConfiguration
    case badConnection
    case cancelled
    case disconnected
    case internalError
}
