//
//  MasterViewController.swift
//  Moonbounce.iOS
//
//  Created by Adelita Schule on 1/11/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import UIKit
import NetworkExtension

class MasterViewController: UITableViewController, UIDocumentPickerDelegate
{
    var detailViewController: DetailViewController? = nil
    
    let tunnelManager = TunnelController()
    
    /// A list of NEVPNManager objects for the packet tunnel configurations.
    //var tunnels = [Tunnel]()
    //var managers = [NEVPNManager]()

    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        navigationItem.leftBarButtonItem = editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItem = addButton
        
        if let split = splitViewController
        {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
    }

    override func viewWillAppear(_ animated: Bool)
    {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
        
        self.stopObservingStatus()
        tunnelManager.reloadTunnels
        {
            maybeError in
            
            self.observeStatus()
        }
    }
    
    /// Register for configuration change notifications.
    func observeStatus()
    {
//        for (index, tunnel) in tunnelManager.tunnels.enumerated()
//        {
//            NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: tunnel.targetManager.connection, queue: OperationQueue.main, using:
//            {
//                notification in
//                
//                self.tableView.reloadRows(at: [ IndexPath(row: index, section: 0) ], with: .fade)
//            })
//        }
    }
    
    /// De-register for configuration change notifications.
    func stopObservingStatus()
    {
        for tunnel in tunnelManager.tunnels
        {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NEVPNStatusDidChange, object: tunnel.targetManager.connection)
        }
    }

    @objc
    func insertNewObject(_ sender: Any)
    {
        tunnelManager.addDemoTunnel
        {
            (maybeError) in
            
            self.tableView.reloadData()
        }
//        let documentPicker = UIDocumentPickerViewController(documentTypes: ["Moonbounce"], in: .import)
//        documentPicker.delegate = self
//        present(documentPicker, animated: true, completion: nil)
    }
    
    func getFileURL() -> URL?
    {
//        let fileBrowser = FileBrowser()
//        self.presentViewController(fileBrowser, animated: true, completion: nil)
        
        return nil
    }
    
    // MARK: - Document Picker Delegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        for fileURL in urls
        {
            //let configAdded = configController.addConfig(atURL: fileURL)
            
//            guard configAdded
//                else { return }
            
            let indexPath = IndexPath(row: 0, section: 0)
            tableView.insertRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if segue.identifier == "showDetail"
        {
            if let indexPath = tableView.indexPathForSelectedRow
            {
                //let tunnel = configController.configs[indexPath.row]
                let tunnel = tunnelManager.tunnels[indexPath.row]
                //let manager = managers[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = tunnel
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        //return configController.configs.count
        return tunnelManager.tunnels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let tunnel = tunnelManager.tunnels[indexPath.row]
        
        cell.textLabel!.text = tunnel.targetManager.localizedDescription
        
//        let tunnel = configController.configs[indexPath.row]
//
//        cell.textLabel!.text = tunnel.name
        
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
    {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete
        {
            tunnelManager.removeTunnel(atIndex: indexPath.row)
            {
                (maybeError) in
                
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
        else if editingStyle == .insert
        {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }


}

