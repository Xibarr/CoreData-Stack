//  Created by Xibarr on 30/05/16.
//  Copyright © 2016 Xibarr. All rights reserved.
//

import Foundation
import CoreData


class CoreDataCloudStack {
    
    var modelName: String
    var context: NSManagedObjectContext
    var mom: NSManagedObjectModel?
    var psc: NSPersistentStoreCoordinator?
    
    init(modelName: String, ubiquitousName: String, concurrencyType: NSManagedObjectContextConcurrencyType, storeLocation: NSSearchPathDirectory = .DocumentDirectory) {
        
        // Set the name of the model
        self.modelName = modelName
        
        // Get the Model file's URL
        guard let modelURL = NSBundle.mainBundle().URLForResource(modelName, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        
        // Get the Managed Object Model
        mom = NSManagedObjectModel(contentsOfURL: modelURL)
        if mom == nil { fatalError("Error initializing mom from: \(modelURL)") }
        
        // Define the Persistent Store Coordinator
        psc = NSPersistentStoreCoordinator(managedObjectModel: mom!)
        context = NSManagedObjectContext(concurrencyType: concurrencyType)
        context.persistentStoreCoordinator = psc
        
        // Set the Persistent Store in the Document directory (SQLite type)
        let urls = NSFileManager.defaultManager().URLsForDirectory(storeLocation, inDomains: .UserDomainMask)
        let docURL = urls[urls.endIndex-1]
        
        // Local Store setup
        let localStoreURL = docURL.URLByAppendingPathComponent("local\(self.modelName).sqlite")
        var localStoreOptions : [NSObject : AnyObject] = [:]
        localStoreOptions[NSReadOnlyPersistentStoreOption] = true
        
        
        // Cloud Store setup
        let cloudStoreURL = docURL.URLByAppendingPathComponent("\(self.modelName).sqlite")
        var cloudStoreOptions : [NSObject : AnyObject] = [:]
        //cloudStoreOptions[NSPersistentStoreUbiquitousContentNameKey] = ubiquitousName
        cloudStoreOptions = [NSPersistentStoreUbiquitousContentNameKey: ubiquitousName, NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        
        // Check if iCloud is Enabled
        let isiCloudEnabled = NSFileManager.defaultManager().ubiquityIdentityToken // NIL if no cloud available (log out or iCloud Disabled)
        
        
        registerNotification()
        
        // Check if iCloud is available
        // If user is not logged in or iCloud Drive is off we create a localStore
        guard isiCloudEnabled != nil else { // If iCloud not available we use localStore
            do {
                try self.psc!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: localStoreURL, options: nil)
            } catch {
                fatalError("Error migrating store: \(error)")
            }
            return
        }
        
        
        // If iCloud is available then we seed the localStore to iCloud (only happen once)
        let kvStore = NSUbiquitousKeyValueStore.defaultStore()
        let localStoreExist = NSFileManager.defaultManager().fileExistsAtPath(localStoreURL.path!)
        if !kvStore.boolForKey("SEED_DATA_FROM_LOCAL_STORE") && localStoreExist { // If no data has been send to iCloud before
            
            let localStore = try! psc?.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: localStoreURL, options: localStoreOptions)
            
            let queue = NSOperationQueue()
            queue.addOperationWithBlock {
                
                let cloudStore = try! self.psc!.migratePersistentStore(localStore!, toURL: cloudStoreURL, options:cloudStoreOptions, withType: NSSQLiteStoreType)
                
                
                _ = cloudStore.URL
                
                kvStore.setBool(true, forKey: "SEED_DATA_FROM_LOCAL_STORE")
                let mainQueue = NSOperationQueue.mainQueue()
                
                mainQueue.addOperationWithBlock{
                    // update UI
                    // Detect duplicate
                    CDDeduplicator.deDuplicateEntityWithName("Favorite", uniqueAttributeName: "entryID", backgroundMoc: self.context)
                    
                }
            }
            
            
        } else { // Data already been seeded in the past
            // Add persitent store normaly
            do {
                try self.psc!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: cloudStoreURL, options: cloudStoreOptions)
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }
        
    }
    
    func registerNotification() {
        
        // When the iCloud Account is about to change we save the context
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector:Selector(persistentStoreCoordinatorWillChangeStores()), name:NSPersistentStoreCoordinatorStoresWillChangeNotification, object: psc)
        // When a new iCloud Account is used
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(CoreDataCloudStack.persistentStoreCoordinatorDidChangeStores(_:)),
                                                         name: NSPersistentStoreCoordinatorStoresDidChangeNotification, object: psc)
        
        //observe the right iCloud event
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(CoreDataCloudStack.persistentStoreDidImportUbiquitousContentChanges),
                                                         name: NSPersistentStoreDidImportUbiquitousContentChangesNotification,
                                                         object:psc)
    }
    
    
    
    @objc func persistentStoreDidImportUbiquitousContentChanges(notification: NSNotification) {
        
        CDDeduplicator.deDuplicateEntityWithName("NAME", uniqueAttributeName: "ID", backgroundMoc: self.context)
        
    }
    
    func persistentStoreCoordinatorWillChangeStores(){
        if context.hasChanges {
            do {
                try context.save()
            } catch let error as NSError {
                
                print("Error: \(error.localizedDescription)")
            }
        }
        context.reset()
    }
    
    
    @objc func persistentStoreCoordinatorDidChangeStores(notification: NSNotification) {
        // Store is Ready
        
    }
    
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    
    
    
}