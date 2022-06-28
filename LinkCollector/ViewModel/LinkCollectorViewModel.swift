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
import SwiftSoup
import UserNotifications
import FaviconFinder
import os
import Persistence

class LinkCollectorViewModel: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let logger = Logger()
    private let contentsJson = "contents.json"
    
    private let persistence: Persistence
    private var persistenceContainer: NSPersistentCloudKitContainer {
        persistence.container
    }
    
    private var subscriptions: Set<AnyCancellable> = []
    
    @Published var changedPeristentContext = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    @Published var userLatitude: Double = 0
    @Published var userLongitude: Double = 0
    @Published var userLocality: String = "Unknown"
    @Published var showAlert = false
    
    @Published var toggle = false
    
    @Published var selected = UUID()
    @Published var searchString = ""
    @Published var selectedTags = Set<TagEntity>()
    
    @Published var dateInterval: DateInterval?
    
    var message = ""
    
    init(persistence: Persistence) {
        self.persistence = persistence
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
    
    // MARK: - LocationManager
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
    
    func isValid(urlString: String) -> Bool {
        guard let urlComponent = URLComponents(string: urlString), let scheme = urlComponent.scheme else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
    
    private func getURLAndHTML(from urlString: String) -> (URL?, String?) {
        var url: URL?
        var html: String?
        
        if isValid(urlString: urlString) {
            (url, html) = tryDownloadHTML(from: urlString)
        } else {
            (url, html) = tryDownloadHTML(from: "https://\(urlString)")
            if html == nil {
                (url, html) = tryDownloadHTML(from: "http://\(urlString)")
            }
        }
        return (url, html)
    }
        
    private func tryDownloadHTML(from urlString: String) -> (URL?, String?) {
        if let url = URL(string: urlString) {
            return (url, try? String(contentsOf: url))
        } else {
            return (nil, nil)
        }
    }
    
    func process(urlString: String, completionHandler: @escaping (_ result: String?, _ correctedURL: URL?) -> Void) -> Void {
        let (url, html) = getURLAndHTML(from: urlString)
        
        guard let url = url, let html = html else {
            completionHandler(nil, nil)
            return
        }
        
        let htmlParser = HTMLParser()
        htmlParser.parse(url: url, html: html) { result in
            completionHandler(result, url)
        }
    }
    
    func findFavicon(url: URL, completionHandler: @escaping (_ favicon: Data?, _ error: Error?) -> Void) {
        FaviconFinder(url: url).downloadFavicon { result in
            switch result {
            case .success(let favicon):
                completionHandler(favicon.data, nil)
            case .failure(let error):
                completionHandler(nil, error)
            }
        }
    }
    
    // MARK: - Persistence
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
                    
                    DispatchQueue.main.async {
                        self.message = "Cannot update title = \(self.linkDTO.title) and note = \(self.linkDTO.note)"
                        self.showAlert.toggle()
                    }
                }
                
                DispatchQueue.main.async {
                    self.toggle.toggle()
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
                let entity = TagEntity(context: persistenceContainer.viewContext)
                entity.id = UUID()
                entity.name = tagDTO.name
                entity.created = Date()
            }
            
            do {
                try saveContext()
            } catch {
                let nsError = error as NSError
                print("While saving \(tagDTO) occured an unresolved error \(nsError), \(nsError.userInfo)")
                
                DispatchQueue.main.async {
                    self.message = "Cannot save tag = \(self.tagDTO.name)"
                    self.showAlert.toggle()
                }
            }
            
            DispatchQueue.main.async {
                self.toggle.toggle()
            }
        }
    }
    
    func update(link: LinkDTO, with tags: [TagEntity]) -> Void {
        if let linkEntity = getLinkEntity(id: link.id) {
            if let tagEntites = linkEntity.tags {
                linkEntity.removeFromTags(tagEntites)
            }
            
            linkEntity.addToTags(NSSet(array: tags))
        }
        
        do {
            try saveContext()
        } catch {
            let nsError = error as NSError
            print("While removing tags from \(link) occured an unresolved error \(nsError), \(nsError.userInfo)")
            DispatchQueue.main.async {
                self.message = "Cannot save link = \(link.title)"
                self.showAlert.toggle()
            }
        }
        
        DispatchQueue.main.async {
            self.toggle.toggle()
        }
    }
    
    func remove(tag: String, from link: LinkDTO) {
        if let linkEntity = getLinkEntity(id: link.id), let tagEntity = getTagEntity(with: tag) {
            tagEntity.removeFromLinks(linkEntity)
        }
        
        do {
            try saveContext()
        } catch {
            let nsError = error as NSError
            print("While removing \(tag) from \(link) occured an unresolved error \(nsError), \(nsError.userInfo)")
            DispatchQueue.main.async {
                self.message = "Cannot save link = \(link.title)"
                self.showAlert.toggle()
            }
        }
        
        DispatchQueue.main.async {
            self.toggle.toggle()
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
            fetchedLinks = try persistenceContainer.viewContext.fetch(fetchRequest)
        } catch {
            let nsError = error as NSError
            print("While fetching LinkEntity with id=\(id) occured an unresolved error \(nsError), \(nsError.userInfo)")
            DispatchQueue.main.async {
                self.message = "Cannot find a link with id=\(id)"
                self.showAlert.toggle()
            }
        }
        
        return fetchedLinks.isEmpty ? nil : fetchedLinks[0]
    }
    
    private func getTagEntity(with name: String) -> TagEntity? {
        let predicate = NSPredicate(format: "name == %@", argumentArray: [name])
        
        let fetchRequest = NSFetchRequest<TagEntity>(entityName: "TagEntity")
        fetchRequest.predicate = predicate
        
        var fetchedTags = [TagEntity]()
        do {
            fetchedTags = try persistenceContainer.viewContext.fetch(fetchRequest)
        } catch {
            let nsError = error as NSError
            print("While fetching TagEntity with name=\(name) occured an unresolved error \(nsError), \(nsError.userInfo)")
            DispatchQueue.main.async {
                self.message = "Cannot find a tag with name=\(name)"
                self.showAlert.toggle()
            }
        }
        
        return fetchedTags.isEmpty ? nil : fetchedTags[0]
    }
    
    func saveContext() throws -> Void {
        persistenceContainer.viewContext.transactionAuthor = "App"
        try persistenceContainer.viewContext.save()
        persistenceContainer.viewContext.transactionAuthor = nil
    }
    
    // MARK: - Persistence History Request
    private func fetchUpdates(_ notification: Notification) -> Void {
        persistence.fetchUpdates(notification) { result in
            switch result {
            case .success(()):
                DispatchQueue.main.async {
                    self.toggle.toggle()
                }
            case .failure(let error):
                self.logger.log("Error while updating history: \(error.localizedDescription, privacy: .public) \(Thread.callStackSymbols, privacy: .public)")
                
                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    self.logger.log("version=\(version, privacy: .public)")
                    if version == "1.4.1" {
                        self.logger.log("try to invalidate token")
                        self.persistence.invalidateHistoryToken()
                    }
                }
            }
        }
    }
    
    // MARK: - Widget
    func writeWidgetEntries() {
        let fetchRequest: NSFetchRequest<LinkEntity> = LinkEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
        
        let fc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: persistenceContainer.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        do {
            try fc.performFetch()
        } catch {
            logger.log("Failed fetch LinkEntity")
        }
        
        guard let entities = fc.fetchedObjects else {
            return
        }
        
        guard entities.count > 0 else {
            return
        }
        
        var widgetEntries = [WidgetEntry]()
    
        let numberOfWidgetEntries = 6
        
        // Randomly select 6 records to provide widgets per hour
        for _ in 0..<numberOfWidgetEntries {
            let entity = entities[Int.random(in: 0..<entities.count)]
            if let id = entity.id, let title = entity.title, let created = entity.created, let url = entity.url {
                widgetEntries.append(WidgetEntry(id: id, title: title, url: url, created: created, favicon: entity.favicon))
            }
        }
        
        let archiveURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: LinkPilerConstants.groupIdentifier.rawValue)!
        logger.log("archiveURL=\(archiveURL)")
        
        let encoder = JSONEncoder()
        
        if let dataToSave = try? encoder.encode(widgetEntries) {
            do {
                try dataToSave.write(to: archiveURL.appendingPathComponent(contentsJson))
                logger.log("Saved \(widgetEntries.count) widgetEntries")
            } catch {
                logger.log("Error: Can't write contents")
                return
            }
        }
    }
    
}

extension LinkCollectorViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      guard let location = locations.last else { return }
      userLatitude = location.coordinate.latitude
      userLongitude = location.coordinate.longitude
    }
}
