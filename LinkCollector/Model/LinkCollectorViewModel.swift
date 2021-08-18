//
//  LocationViewModel.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/19/20.
//

import Foundation
import Combine
import CoreLocation
import CoreData

class LinkCollectorViewModel: NSObject, ObservableObject {
    @Published var userLatitude: Double = 0
    @Published var userLongitude: Double = 0
    @Published var userLocality: String = "Unknown"
    
    private let locationManager = CLLocationManager()
    
    private let persistenteContainer = PersistenceController.shared.container
    private var subscriptions: Set<AnyCancellable> = []
    
    @Published var showAlert = false
    var message = ""
    
    var linkDTO = LinkDTO(id: UUID(), title: "", note: "") {
        didSet {
            if let existingEntity = getLinkEntity(id: linkDTO.id) {
                existingEntity.title = linkDTO.title
                existingEntity.note = linkDTO.note

                print("existingEntity = \(existingEntity)")
                
                do {
                    try saveContext()
                } catch {
                    let nsError = error as NSError
                    print("While saving \(linkDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
                    message = "Cannot update title = \(linkDTO.title) and note = \(linkDTO.note)"
                    showAlert.toggle()
                }
            }
        }
    }
    
    override init() {
        super.init()
        
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
        lookUpCurrentLocation()
        
        NotificationCenter.default
          .publisher(for: .NSPersistentStoreRemoteChange)
          .sink { self.fetchUpdates($0) }
          .store(in: &subscriptions)
    }
    
    private func getLinkEntity(id: UUID) -> LinkEntity? {
        let predicate = NSPredicate(format: "id == %@", argumentArray: [id])
        
        let fetchRequest = NSFetchRequest<LinkEntity>(entityName: "LinkEntity")
        fetchRequest.predicate = predicate
        
        var fetchedLinks = [LinkEntity]()
        do {
            fetchedLinks = try persistenteContainer.viewContext.fetch(fetchRequest)
            
            print("fetchedLinks = \(fetchedLinks)")
        } catch {
            fatalError("Failed to fetch link: \(error)")
        }
        
        return fetchedLinks.isEmpty ? nil : fetchedLinks[0]
    }
    
    private func saveContext() throws -> Void {
        persistenteContainer.viewContext.transactionAuthor = "App"
        try persistenteContainer.viewContext.save()
        persistenteContainer.viewContext.transactionAuthor = nil
    }
    
    func lookUpCurrentLocation() {
        if let lastLocation = locationManager.location {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(lastLocation) { (placemarks, error) in
                if error == nil {
                    self.userLocality = placemarks?[0].locality ?? "Unknown"
                } else {
                    self.userLocality = "Unknown"
                }
            }
        } else {
            self.userLocality = "Unknown"
        }
    }
    
    private lazy var historyRequestQueue = DispatchQueue(label: "history")
    private func fetchUpdates(_ notification: Notification) -> Void {
        historyRequestQueue.async {
            print("subscriptions.count = \(self.subscriptions.count)")
            let backgroundContext = self.persistenteContainer.newBackgroundContext()
            backgroundContext.performAndWait {
                do {
                    let fetchHistoryRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
                    
                    if let historyResult = try backgroundContext.execute(fetchHistoryRequest) as? NSPersistentHistoryResult,
                       let history = historyResult.result as? [NSPersistentHistoryTransaction] {
                        for transaction in history.reversed() {
                            //print("transaction: author = \(transaction.author), contextName = \(transaction.contextName), storeId = \(transaction.storeID), timeStamp = \(transaction.timestamp), \(transaction.objectIDNotification())")
                            self.persistenteContainer.viewContext.perform {
                                if let userInfo = transaction.objectIDNotification().userInfo {
                                    //print("transaction.objectIDNotification().userInfo = \(userInfo)")
                                    if let insertedObjectIds = userInfo["inserted_objectsIDs"] {
                                        if let idSet = insertedObjectIds as? NSSet {
                                            for id in idSet {
                                                print("inserted_objectsIDs: \(id) - \(self.persistenteContainer.viewContext.object(with: id as! NSManagedObjectID))")
                                            }
                                        }
                                    } else if let updatedObjectIds = userInfo["updated_objectIDs"] {
                                        if let idSet = updatedObjectIds as? NSSet {
                                            for id in idSet {
                                                print("updated_objectID: \(id) - \(self.persistenteContainer.viewContext.object(with: id as! NSManagedObjectID))")
                                            }
                                        }
                                    }
                                    
                                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo,
                                                                        into: [self.persistenteContainer.viewContext])
                                }
                            }
                        }
                        
                        self.lastToken = history.last?.token
                    }
                } catch {
                    print("Could not convert history result to transactions after lastToken = \(String(describing: self.lastToken)): \(error)")
                }
            }
        }
    }
    
    private var lastToken: NSPersistentHistoryToken? = nil {
        didSet {
            guard let token = lastToken,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
                return
            }
            
            do {
                try data.write(to: tokenFile)
            } catch {
                let message = "Could not write token data"
                print("###\(#function): \(message): \(error)")
            }
        }
    }
    
    lazy var tokenFile: URL = {
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("LinkCollector",isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } catch {
                let message = "Could not create persistent container URL"
                print("###\(#function): \(message): \(error)")
            }
        }
        return url.appendingPathComponent("token.data", isDirectory: false)
    }()
    
}

extension LinkCollectorViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      guard let location = locations.last else { return }
      userLatitude = location.coordinate.latitude
      userLongitude = location.coordinate.longitude
      print(location)
    }
}