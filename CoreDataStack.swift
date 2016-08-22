//  Created by Xibarr on 30/05/16.
//  Copyright © 2016 Xibarr. All rights reserved.
//

import Foundation
import CoreData


class CoreDataStack {
    
    var modelName: String
    var context: NSManagedObjectContext
    var mom: NSManagedObjectModel?
    var psc: NSPersistentStoreCoordinator?
    
    init(modelName: String, concurrencyType: NSManagedObjectContextConcurrencyType, storeLocation: NSSearchPathDirectory = .DocumentDirectory) {
        
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
        
        let storeURL = docURL.URLByAppendingPathComponent("\(self.modelName).sqlite")
        
        registerNotification()
        
        do {
            try self.psc!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
        } catch {
            fatalError("Error migrating store: \(error)")
        }
        
    }
    
    
    // Save the Context (if needed)
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch let error as NSError {
                print("Error: \(error.localizedDescription)")
                abort()
            }
        }
    }
    
    
    
    func registerNotification() {
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector:Selector(persistentStoreCoordinatorWillChangeStores()), name:NSPersistentStoreCoordinatorStoresWillChangeNotification, object: psc)
    }
    
    
    
    // Save the current context or reset it
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
    
    
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    
}

