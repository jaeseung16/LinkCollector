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
    
    var tagDTO = TagDTO(name: "", link: nil) {
        didSet {
            if let tagEntity = getTagEntity(with: tagDTO.name) {
                if let link = tagDTO.link, let linkEntity = getLinkEntity(id: link.id) {
                    if let links = tagEntity.links {
                        if !links.contains(linkEntity) {
                            tagEntity.addToLinks(linkEntity)
                        }
                    }
                } else {
                    message = "A tag \"\(tagDTO.name)\" already exists"
                    showAlert.toggle()
                }
            } else {
                let entity = TagEntity(context: persistenteContainer.viewContext)
                entity.id = UUID()
                entity.name = tagDTO.name
                entity.created = Date()
            }
            
            do {
                try saveContext()
            } catch {
                let nsError = error as NSError
                print("While saving \(tagDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
                message = "Cannot save tag = \(tagDTO.name)"
                showAlert.toggle()
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
    
    func remove(tag: String, from link: LinkDTO) {
        if let linkEntity = getLinkEntity(id: link.id), let tagEntity = getTagEntity(with: tag) {
            tagEntity.removeFromLinks(linkEntity)
        }
    }
    
    func getTagList(of link: LinkEntity) -> [String] {
        var tagList = [String]()
        
        if let tags = link.tags {
            for tag in tags {
                if let tag = tag as? TagEntity {
                    if let name = tag.name {
                        tagList.append(name)
                    }
                }
            }
        }
        return tagList
    }
    
    private func getLinkEntity(id: UUID) -> LinkEntity? {
        let predicate = NSPredicate(format: "id == %@", argumentArray: [id])
        
        let fetchRequest = NSFetchRequest<LinkEntity>(entityName: "LinkEntity")
        fetchRequest.predicate = predicate
        
        var fetchedLinks = [LinkEntity]()
        do {
            fetchedLinks = try persistenteContainer.viewContext.fetch(fetchRequest)
        } catch {
            fatalError("Failed to fetch link: \(error)")
        }
        
        return fetchedLinks.isEmpty ? nil : fetchedLinks[0]
    }
    
    private func getTagEntity(with name: String) -> TagEntity? {
        let predicate = NSPredicate(format: "name == %@", argumentArray: [name])
        
        let fetchRequest = NSFetchRequest<TagEntity>(entityName: "TagEntity")
        fetchRequest.predicate = predicate
        
        var fetchedTags = [TagEntity]()
        do {
            fetchedTags = try persistenteContainer.viewContext.fetch(fetchRequest)
        } catch {
            fatalError("Failed to fetch link: \(error)")
        }
        
        return fetchedTags.isEmpty ? nil : fetchedTags[0]
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
    
    // MARK: - Persistence History Request
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
                            self.persistenteContainer.viewContext.perform {
                                if let userInfo = transaction.objectIDNotification().userInfo {
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
    }
}
