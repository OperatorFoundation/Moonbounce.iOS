//
//  Tunnel.swift
//  Moonbounce.iOS
//
//  Created by Mafalda on 2/15/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

class Tunnel
{
    var targetManager: NEVPNManager = NEVPNManager.shared()
    
    init(protocolConfiguration: NETunnelProviderProtocol, serverAddress: String, name: String)
    {
        targetManager.isOnDemandEnabled = false
        targetManager.protocolConfiguration = protocolConfiguration
        targetManager.protocolConfiguration?.serverAddress = serverAddress
        targetManager.isEnabled = true
    }
    
    init(targetManager: NEVPNManager)
    {
        self.targetManager = targetManager
    }
    
    /// Dev purposes only! Creates a demo tunnel.
    init(completionHandler: @escaping ((Error?) -> Void))
    {
        let newManager = NETunnelProviderManager()
        newManager.protocolConfiguration = NETunnelProviderProtocol()
        newManager.localizedDescription = "Demo VPN"
        newManager.protocolConfiguration?.serverAddress = "127.0.0.1"
       // newManager.protocolConfiguration
        newManager.isEnabled = true
        
        newManager.saveToPreferences
        {
            maybeError in
            
            guard maybeError == nil
                else
            {
                print("\nFailed to save the configuration: \(maybeError!)\n")
                completionHandler(maybeError)
                return
            }
            
            newManager.loadFromPreferences(completionHandler:
            {
                (maybeError) in
                
                if let error = maybeError
                {
                    print("\nError loading from preferences!\(error)\n")
                    completionHandler(error)
                    return
                }
                
                self.targetManager = newManager
                completionHandler(nil)
            })
        }
    }
}
