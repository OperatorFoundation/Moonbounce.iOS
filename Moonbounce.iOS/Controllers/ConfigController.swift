//
//  configController.swift
//  Moonbounce.iOS
//
//  Created by Mafalda on 1/18/19.
//  Copyright © 2019 Operator Foundation. All rights reserved.
//

import Foundation
import ZIPFoundation
import ReplicantSwift

class  ConfigController
{
    let fileManager = FileManager.default
    let configsDirectory: URL
    
    var configs = [MoonbounceConfig]()
    
    init(withDirectory directoryURL: URL)
    {
        self.configsDirectory = directoryURL
    }
    
    convenience init?()
    {
        guard let configsURL = ConfigController.getConfigDirectory()
            else
        {
            return nil
        }
        
        self.init(withDirectory: configsURL)
    }
    
    func addConfig(atURL url: URL) -> Bool
    {
        let configName = fileManager.displayName(atPath: url.path)
            //url.deletingPathExtension().lastPathComponent
        let thisConfigURL = url.appendingPathComponent(configName)
        do
        {
            try fileManager.createDirectory(at: thisConfigURL, withIntermediateDirectories: true, attributes: nil)
            
            if configFilesAreValid(atURL: thisConfigURL)
            {
                return true
            }
            else
            {
                do
                {
                    try fileManager.unzipItem(at: url, to: thisConfigURL, progress: nil)
                    
                    if configFilesAreValid(atURL: thisConfigURL)
                    {
                        return true
                    }
                }
                catch let error
                {
                    print("Error creating config directory: \(error)")
                    return false
                }
            }
        }
            
        catch let error
        {
            print("Unable to create configs directory: \(error)")
            return false
        }
        
        return false
    }
    
    func removeConfig(atURL url: URL) -> Bool
    {
        do
        {
            try FileManager.default.removeItem(at: url)
            return true
        }
        catch let error
        {
            print("\nError deleting config at \(url): \(error)\n")
            return false
        }
    }
    
    func configFilesAreValid(atURL configURL: URL) -> Bool
    {
        do
        {
            let fileManager = FileManager.default
            if let fileEnumerator = fileManager.enumerator(at: configURL, includingPropertiesForKeys: [.nameKey], options: [.skipsHiddenFiles], errorHandler:
                {
                    (url, error) -> Bool in
                    
                    print("File enumerator error at \(configURL.path): \(error.localizedDescription)")
                    return true
            })
            {
                //Verify  that each of the following files are present as all config files are neccessary for successful connection:
                let file1 = "replicant.config"
                let file2 = "wireguard.config"
                let file3 = "replicantClient.config"
                
                var fileNames = [String]()
                for case let fileURL as URL in fileEnumerator
                {
                    let fileName = try fileURL.resourceValues(forKeys: Set([.nameKey]))
                    if fileName.name != nil
                    {
                        fileNames.append(fileName.name!)
                    }
                }
                
                //If all required files are present refresh server select button
                if fileNames.contains(file1) && fileNames.contains(file2) && fileNames.contains(file3)
                {
                    guard let replicantConfig = ReplicantConfig(withConfigAtPath: configURL.appendingPathComponent(file1).path)
                    else
                    {
                        print("Unable to create replicant config from file at \(configURL.appendingPathComponent(file1))")
                        
                        return false
                    }
                    
                    let moonbounceConfig = MoonbounceConfig(name: configURL.lastPathComponent, replicantConfig: replicantConfig)
                    
                    self.configs.append(moonbounceConfig)
                    
                    return true
                }
            }
        }
        catch
        {
            return false
        }
        
        return false
    }
    
    static func documentsDirectoryURL() -> URL?
    {
        if let docDirectory =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            return docDirectory
        }
        else
        {
            return nil
        }
    }
    
    static func getConfigDirectory() -> URL?
    {
        
        guard let appDocumentsDirectory = documentsDirectoryURL()
        else
        {
            return nil
        }
        
        let configsURL = appDocumentsDirectory.appendingPathComponent("Configs")
        
        return configsURL
    }
}
