//
//  File.swift
//  MoonbounceiOSNetworkExtension
//
//  Created by Mafalda on 2/12/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

/// An object used to tunnel IP packets using the SimpleTunnel protocol.
public class ClientTunnelConnection
{
    /// The flow of IP packets.
    let packetFlow: NEPacketTunnelFlow
    
    // MARK: Initializers
    
    init(clientPacketFlow: NEPacketTunnelFlow)
    {
        packetFlow = clientPacketFlow
    }
    
    // MARK: Interface
    
    /// Handle packets coming from the packet flow.
    func handlePackets(_ packets: [Data], protocols: [NSNumber])
    {
        // This is where you should send the packets to the server.
        
        // Read more packets.
        self.packetFlow.readPackets
        {
            inPackets, inProtocols in
            
            self.handlePackets(inPackets, protocols: inProtocols)
        }
    }
    
    /// Make the initial readPacketsWithCompletionHandler call.
    func startHandlingPackets()
    {
        packetFlow.readPackets
        {
            inPackets, inProtocols in
            
            self.handlePackets(inPackets, protocols: inProtocols)
        }
    }
    
    /// Send packets to the virtual interface to be injected into the IP stack.
    public func sendPackets(_ packets: [Data], protocols: [NSNumber])
    {
        packetFlow.writePackets(packets, withProtocols: protocols)
    }
}
