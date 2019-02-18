//
//  TunnelController.swift
//  Moonbounce.iOS
//
//  Created by Mafalda on 2/15/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

class TunnelController
{
    var tunnels = [Tunnel]()
    
    init()
    {
        reloadTunnels
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("\nreceived an error while loading tunnels: \(error)\n")
            }
        }
    }

    func reloadTunnels(completionHandler:@escaping ((Error?) -> Void))
    {
        NETunnelProviderManager.loadAllFromPreferences()
        {
            newManagers, error in
            
            guard let vpnManagers = newManagers else { return }
            
            for manager in vpnManagers
            {
                let tunnel = Tunnel(targetManager: manager)
                self.tunnels.append(tunnel)
            }
            
//            self.stopObservingStatus()
//            self.managers = vpnManagers
//            self.observeStatus()
//            
//            // If there are no configurations, automatically go into editing mode.
//            if self.managers.count == 0 && !self.isEditing
//            {
//                self.setEditing(true, animated: false)
//            }
            completionHandler(error)
        }
    }
    
    func removeTunnel(atIndex index: Int, completionHandler:@escaping ((Error?) -> Void))
    {
        guard index < tunnels.count
        else
        {
            completionHandler(nil)
            return
        }
        
        let tunnel = tunnels[index]
        tunnel.targetManager.removeFromPreferences
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("\nError removing tunnel from preferences: \n\(error)\n")
                return
            }
            
            self.tunnels.remove(at: index)
            self.reloadTunnels(completionHandler:{_ in })
            completionHandler(maybeError)
        }
    }
    
    func addDemoTunnel(completionHandler:@escaping ((Error?) -> Void))
    {
        guard tunnels.isEmpty
        else
        {
            print("\nNot creating demo tunnel as \(tunnels.count) tunnels already exist.\n")
            for tunnel in tunnels
            {
                print(tunnel.targetManager.localizedDescription ?? "Unnamed Tunnel")
                print(tunnel.targetManager.protocolConfiguration ?? "No Protocol Config\n")
            }
            
            return
        }
        
        _ = Tunnel
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("\nreceived an error creating a demo tunnel: \(error)\n")
                return
            }
            
            self.reloadTunnels(completionHandler:
            {
                (maybeError) in
                
                completionHandler(maybeError)
            })
        }
    }
}
