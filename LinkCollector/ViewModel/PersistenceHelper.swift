//
//  PersistenceHelper.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 8/22/23.
//

import Foundation
import CoreData
import os
@preconcurrency import Persistence

final class PersistenceHelper: Sendable {
    private static let logger = Logger()
    
    private let persistence: Persistence
    var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }
    
    init(persistence: Persistence) {
        self.persistence = persistence
    }
    
    func saveContext() throws -> Void {
        if viewContext.hasChanges {
            viewContext.transactionAuthor = "App"
            try viewContext.save()
            viewContext.transactionAuthor = nil
        }
    }
    
    func save() async throws -> Void {
        if viewContext.hasChanges {
            viewContext.transactionAuthor = "App"
            try await persistence.save()
            viewContext.transactionAuthor = nil
        }
    }
    
    func delete(_ object: NSManagedObject) -> Void {
        viewContext.delete(object)
    }
    
    func perform<Element>(_ fetchRequest: NSFetchRequest<Element>) -> [Element] {
        var fetchedEntities = [Element]()
        do {
            fetchedEntities = try viewContext.fetch(fetchRequest)
        } catch {
            PersistenceHelper.logger.error("Failed to fetch with fetchRequest=\(fetchRequest, privacy: .public): error=\(error.localizedDescription, privacy: .public)")
        }
        return fetchedEntities
    }
    
    func getFetchRequest<Entity: NSFetchRequestResult>(for type: Entity.Type, entityName: String, sortDescriptors: [NSSortDescriptor] = [], predicate: NSPredicate? = nil) -> NSFetchRequest<Entity> {
        let fetchRequest = NSFetchRequest<Entity>(entityName: entityName)
        if !sortDescriptors.isEmpty {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }
        return fetchRequest
    }
    
    func fetch<Element>(_ fetchRequest: NSFetchRequest<Element>) -> [Element] {
        var fetchedEntities = [Element]()
        do {
            fetchedEntities = try viewContext.fetch(fetchRequest)
        } catch {
            PersistenceHelper.logger.error("Failed to fetch with fetchRequest=\(fetchRequest, privacy: .public): error=\(error.localizedDescription, privacy: .public)")
        }
        return fetchedEntities
    }
    
    func find(for url: URL) -> NSManagedObject? {
        guard let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) else {
            PersistenceHelper.logger.log("objectID is nil for url=\(url)")
            return nil
        }
        return viewContext.object(with: objectID)
    }
    
    func find(with objectID: NSManagedObjectID) -> NSManagedObject? {
        return viewContext.object(with: objectID)
    }
    
    func getSpotlightDelegate<T: NSCoreDataCoreSpotlightDelegate>() -> T? {
        return persistence.createCoreSpotlightDelegate()
    }
}
