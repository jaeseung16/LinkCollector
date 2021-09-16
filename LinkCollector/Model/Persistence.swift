//
//  Persistence.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/11/21.
//

import CoreData
import os

struct PersistenceController {
    static let shared = PersistenceController()
    static let logger = Logger()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = LinkEntity(context: viewContext)
            newItem.created = Date()
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            PersistenceController.logger.error("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    var container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "LinkCollector")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last else {
                PersistenceController.logger.error("Shared file container could not be created")
                return
            }
            
            let cloudStoreURL = applicationSupportPath.appendingPathComponent("LinkCollector/LinkCollector.sqlite")
            let cloudStoreDescription = NSPersistentStoreDescription(url: cloudStoreURL)
            
            cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            cloudStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            cloudStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.resonance.jaeseung.LinkCollector")
            
            container.persistentStoreDescriptions = [cloudStoreDescription]
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                PersistenceController.logger.error("Could not load persistent store: \(storeDescription), \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.name = "LinkCollector"

        purgeHistory()
    }
    
    private func purgeHistory() {
        let sevenDaysAgo = Date(timeIntervalSinceNow: TimeInterval(exactly: -604_800)!)
        let purgeHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: sevenDaysAgo)

        do {
            try container.newBackgroundContext().execute(purgeHistoryRequest)
        } catch {
            if let error = error as NSError? {
                PersistenceController.logger.error("Could not purge history: \(error), \(error.userInfo)")
            }
        }
    }
    
    func saveContext () {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                if let error = error as NSError? {
                    PersistenceController.logger.error("Could not save: \(error), \(error.userInfo)")
                }
            }
        }
    }
}

