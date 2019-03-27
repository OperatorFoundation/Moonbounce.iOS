//
//  DetailViewController.swift
//  Moonbounce.iOS
//
//  Created by Adelita Schule on 1/11/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import UIKit
import NetworkExtension

class DetailViewController: UIViewController
{
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    /// The target VPN configuration.
    //var targetManager = NEVPNManager.shared()
    //var tunnelManager = TunnelController()
    var loggingEnabled = false
    
    var detailItem: Tunnel?
    {
        didSet
        {
            // Update the view.
            configureView()
        }
    }
    
    @IBAction func connectPressed(_ sender: UIButton)
    {
        activityIndicator.startAnimating()

        guard detailItem != nil
        else
        {
            print("\nConnect button pressed but there is no valid tunnel selected.\n")
            return
        }

        self.detailItem!.targetManager.loadFromPreferences(completionHandler:
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("\nError loading from preferences!\(error)\n")
                return
            }
            
            self.detailItem!.targetManager.saveToPreferences
            {
                (maybeSaveError) in
                
                if let error = maybeSaveError
                {
                    print("Error trying to save to preference after connect was pressed: \(error)")
                    return
                }

                if self.detailItem!.targetManager.connection.status == .disconnected || self.detailItem!.targetManager.connection.status == .invalid
                {
                    print("\nConnect pressed, starting logging loop.\n")
                    self.startLoggingLoop()
                    
                    do
                    {
                        print("\nCalling startVPNTunnel on \(self.detailItem!.targetManager.connection)\n")
                        try self.detailItem!.targetManager.connection.startVPNTunnel()
                    }
                    catch
                    {
                        NSLog("\nFailed to start the VPN: \(error)\n")
                    }
                    self.activityIndicator.stopAnimating()
                }
                else
                {
                    self.stopLoggingLoop()
                    self.detailItem!.targetManager.connection.stopVPNTunnel()
                    self.activityIndicator.stopAnimating()
                }
            }
        })
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        anyoneListening()
        configureView()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        // Register to be notified of changes in the status.
        if detailItem != nil
        {
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange,
                                                   object: detailItem!.targetManager.connection,
                                                   queue: OperationQueue.main,
                                                   using:
            {
                notification in
                
                print("⁉️ View controller notified of change in status: \(self.detailItem!.targetManager.connection.status.description)")
                self.configureView()
            })
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        if detailItem != nil
        {
            // Stop watching for status change notifications.
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: detailItem!.targetManager.connection)
        }
    }
    
    func configureView()
    {
        guard startStopButton != nil
            else { return }
        
        // Update the user interface for the detail item.
        if let detail = detailItem
        {
            self.startStopButton.isHidden = false
            
            if let label = detailDescriptionLabel
            {
                label.text = detail.targetManager.localizedDescription
            }
            
            self.startStopButton.isSelected = (detail.targetManager.connection.status != .disconnected && detail.targetManager.connection.status != .disconnecting && detail.targetManager.connection.status != .invalid)
            statusLabel.text = detail.targetManager.connection.status.description
            navigationItem.title = detail.targetManager.localizedDescription
        }
        else
        {
            self.startStopButton.isHidden = true
            statusLabel.text = "Select a Tunnel"
        }
        
        //startStopButton.isSelected = (targetManager.connection.status != .disconnected && targetManager.connection.status != .invalid)

    }
    
    func anyoneListening()
    {
        guard detailItem != nil
        else
        {
            print("\nUnable to test communications with extension, tunnel is nil.\n")
            return
        }
        
        // Send a simple IPC message to the provider, handle the response.
        let session = detailItem!.targetManager.connection as! NETunnelProviderSession
        if let message = "Hello Provider".data(using: String.Encoding.utf8)
            , detailItem!.targetManager.connection.status != .invalid
        {
            do
            {
                try session.sendProviderMessage(message)
                {
                    response in
                    
                    if response != nil
                    {
                        let responseString: String = NSString(data: response!, encoding: String.Encoding.utf8.rawValue)! as String
                        NSLog("Received response from the provider: \(responseString)")
                    }
                    else
                    {
                        NSLog("Got a nil response from the provider")
                    }
                }
            }
            catch
            {
                NSLog("Failed to send a message to the provider")
            }
        }
        else
        {
            print("\nUnable to send a message, targetManager.connection could not be unwrapped as a NETunnelProviderSession.\n")
        }
    }
    
    @objc func startLoggingLoop()
    {
        loggingEnabled = true
        
        guard detailItem != nil
            else
        {
            print("\nUnable to start communications with extension, tunnel is nil.\n")
            return
        }
        
        // Send a simple IPC message to the provider, handle the response.
        guard let session = detailItem!.targetManager.connection as? NETunnelProviderSession
            else
        {
            print("\nStart logging loop failed:")
            print("Unable to send a message, targetManager.connection could not be unwrapped as a NETunnelProviderSession.")
            print("\(detailItem!.targetManager.connection)\n")
            return
        }
        
        guard detailItem!.targetManager.connection.status != .invalid
            else
        {
            print("\nInvalid connection status")
            return
        }
        
        DispatchQueue.global(qos: .background).async
        {
            var currentStatus = "Unknown"
            while self.loggingEnabled
            {
                sleep(1)
                
                if self.detailItem!.targetManager.connection.status.description != currentStatus
                {
                    currentStatus = self.detailItem!.targetManager.connection.status.description
                    print("\nCurrent Status Changed: \(currentStatus)\n")
                }
                
                guard let message = "Hello Provider".data(using: String.Encoding.utf8)
                    else
                {
                    continue
                }
                
                do
                {
                    try session.sendProviderMessage(message)
                    {
                        response in
                        
                        if response != nil
                        {
                            let responseString: String = NSString(data: response!, encoding: String.Encoding.utf8.rawValue)! as String
                            if responseString != ""
                            {
                                print(responseString)
                            }
                        }
                        else
                        {
                            print("Got a nil response from the provider")
                        }
                    }
                }
                catch
                {
                    NSLog("Failed to send a message to the provider")
                }
                
                DispatchQueue.main.async
                    {
                        // Stub
                }
            }
        }
    }
    
    func stopLoggingLoop()
    {
        loggingEnabled = false
    }


}

