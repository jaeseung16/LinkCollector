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
import UserNotifications
import os
import Persistence
import SwiftUI
import CoreSpotlight

class LinkCollectorViewModel: NSObject, ObservableObject {
    @AppStorage("spotlightLinkIndexing") private var spotlightLinkIndexing: Bool = false
    
    static let unknown = "Unknown"
    
    private let locationManager = CLLocationManager()
    private let logger = Logger()
    private let contentsJson = "contents.json"
    
    private let persistence: Persistence
    private var persistenceContainer: NSPersistentCloudKitContainer {
        persistence.cloudContainer!
    }
    
    private var subscriptions: Set<AnyCancellable> = []
    
    @Published var changedPeristentContext = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    var userLatitude: Double = 0
    var userLongitude: Double = 0
    @Published var userLocality: String = LinkCollectorViewModel.unknown
    @Published var showAlert = false
    
    @Published var selected = UUID()
    @Published var searchString = ""
    
    var message = "" {
        didSet {
            showAlert.toggle()
        }
    }
    
    private let persistenceHelper: PersistenceHelper
    
    private(set) var linkIndexer: LinkSpotlightDelegate?
    private var spotlightFoundLinks: [CSSearchableItem] = []
    private var linkSearchQuery: CSSearchQuery?
    
    init(persistence: Persistence) {
        self.persistence = persistence
        self.persistenceHelper = PersistenceHelper(persistence: persistence)
        
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
        
        if let linkIndexer: LinkSpotlightDelegate = self.persistenceHelper.getSpotlightDelegate() {
            self.linkIndexer = linkIndexer
            self.toggleIndexing(self.linkIndexer, enabled: true)
            NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        }
        
        logger.log("spotlightLinkIndexing=\(self.spotlightLinkIndexing, privacy: .public)")
        if !spotlightLinkIndexing {
            DispatchQueue.main.async {
                self.indexLinks()
                self.spotlightLinkIndexing.toggle()
                
            }
        }
        
    }
    
    // MARK: - CoreSpotlight
    @objc private func defaultsChanged() -> Void {
        if !self.spotlightLinkIndexing {
            DispatchQueue.main.async {
                self.toggleIndexing(self.linkIndexer, enabled: false)
                self.toggleIndexing(self.linkIndexer, enabled: true)
                self.spotlightLinkIndexing.toggle()
            }
        }
    }
    
    private func toggleIndexing(_ indexer: NSCoreDataCoreSpotlightDelegate?, enabled: Bool) {
        guard let indexer = indexer else { return }
        if enabled {
            indexer.startSpotlightIndexing()
        } else {
            indexer.stopSpotlightIndexing()
        }
    }
    
    private func indexLinks() -> Void {
        logger.log("Indexing \(self.links.count, privacy: .public) links")
        index<LinkEntity>(links, indexName: LinkPilerConstants.linkIndexName.rawValue)
    }
    
    private func index<T: NSManagedObject>(_ entities: [T], indexName: String) {
        let searchableItems: [CSSearchableItem] = entities.compactMap { (entity: T) -> CSSearchableItem? in
            guard let attributeSet = attributeSet(for: entity) else {
                self.logger.log("Cannot generate attribute set for \(entity, privacy: .public)")
                return nil
            }
            return CSSearchableItem(uniqueIdentifier: entity.objectID.uriRepresentation().absoluteString, domainIdentifier: LinkPilerConstants.domainIdentifier.rawValue, attributeSet: attributeSet)
        }
        
        logger.log("Adding \(searchableItems.count) items to index=\(indexName, privacy: .public)")
        
        CSSearchableIndex(name: indexName).indexSearchableItems(searchableItems) { error in
            guard let error = error else {
                return
            }
            self.logger.log("Error while indexing \(T.self): \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let link = object as? LinkEntity {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = link.title
            attributeSet.displayName = link.title
            return attributeSet
        }
        return nil
    }
    
    func searchLink() -> Void {
        if searchString.isEmpty {
            linkSearchQuery?.cancel()
            fetchAll()
        } else {
            searchLinks()
        }
    }
    
    private func searchLinks() -> Void {
        let escapedText = searchString.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let queryString = "(title == \"*\(escapedText)*\"cd)"
        
        linkSearchQuery = CSSearchQuery(queryString: queryString, attributes: ["title"])
        
        linkSearchQuery?.foundItemsHandler = { items in
            DispatchQueue.main.async {
                self.spotlightFoundLinks += items
            }
        }
        
        linkSearchQuery?.completionHandler = { error in
            if let error = error {
                self.logger.log("Searching \(self.searchString) came back with error: \(error.localizedDescription, privacy: .public)")
            } else {
                DispatchQueue.main.async {
                    self.fetchLinks(self.spotlightFoundLinks)
                    self.spotlightFoundLinks.removeAll()
                }
            }
        }
        
        linkSearchQuery?.start()
    }
    
    private func fetchLinks(_ items: [CSSearchableItem]) {
        logger.log("Fetching \(items.count) links")
        let fetched = fetch(LinkEntity.self, items)
        logger.log("fetched.count=\(fetched.count)")
        links = fetched.sorted(by: { link1, link2 in
            guard let lastupd1 = link1.lastupd else {
                return false
            }
            guard let lastupd2 = link2.lastupd else {
                return true
            }
            return lastupd1 > lastupd2
        })
        logger.log("Found \(self.links.count) links")
    }
    
    private func fetch<Element>(_ type: Element.Type, _ items: [CSSearchableItem]) -> [Element] where Element: NSManagedObject {
        return items.compactMap { (item: CSSearchableItem) -> Element? in
            guard let url = URL(string: item.uniqueIdentifier) else {
                self.logger.log("url is nil for item=\(item)")
                return nil
            }
            return persistenceHelper.find(for: url) as? Element
        }
    }
    
    func continueActivity(_ activity: NSUserActivity, completionHandler: @escaping (NSManagedObject) -> Void) {
        logger.log("continueActivity: \(activity)")
        guard let info = activity.userInfo, let objectIdentifier = info[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        guard let objectURI = URL(string: objectIdentifier), let entity = persistenceHelper.find(for: objectURI) else {
            logger.log("Can't find an object with objectIdentifier=\(objectIdentifier)")
            return
        }
        
        logger.log("entity = \(entity)")
        
        DispatchQueue.main.async {
            if let link = entity as? LinkEntity {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completionHandler(link)
                }
            }
        }
    }
    
    // MARK: - LocationManager
    func lookUpCurrentLocation() {
        if let lastLocation = locationManager.location {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(lastLocation) { (placemarks, error) in
                if error == nil {
                    self.userLocality = placemarks?[0].locality ?? LinkCollectorViewModel.unknown
                } else {
                    self.userLocality = LinkCollectorViewModel.unknown
                }
            }
        } else {
            self.userLocality = LinkCollectorViewModel.unknown
        }
    }
    
    func lookUpCurrentLocation() async -> String {
        if let lastLocation = locationManager.location {
            do {
                let geocoder = CLGeocoder()
                let placemarks = try await geocoder.reverseGeocodeLocation(lastLocation)
                return placemarks.isEmpty ? LinkCollectorViewModel.unknown : placemarks[0].locality ?? LinkCollectorViewModel.unknown
            } catch {
                logger.log("Cannot find any descriptions for the location: \(lastLocation)")
                return LinkCollectorViewModel.unknown
            }
        } else {
            return LinkCollectorViewModel.unknown
        }
    }
    
    // MARK: - Download
    
    private func getUrlAndHtml(from urlString: String) async -> (URL?, String?) {
        var url: URL?
        var html: String?
        if LinkCollectorDownloader.isValid(urlString: urlString) {
            (url, html) = await LinkCollectorDownloader.download(from: urlString)
        } else {
            (url, html) = await LinkCollectorDownloader.download(from: "https://\(urlString)")
            if html == nil {
                (url, html) = await LinkCollectorDownloader.download(from: "http://\(urlString)")
            }
        }
        return (url, html)
    }

    func process(urlString: String) async -> (URL?, String?) {
        let (url, html) = await getUrlAndHtml(from: urlString)
        
        guard let url = url, let html = html else {
            self.logger.log("Cannot download html from url described by \(urlString, privacy: .public)")
            return (nil, nil)
        }
        
        let htmlParser = HTMLParser()
        let title = await htmlParser.parse(url: url, html: html)
        return (url, title)
    }
    
    func findFavicon(url: URL) async -> Data? {
        return await LinkCollectorDownloader.findFavicon(url: url)
    }
    
    // MARK: - Persistence
    var linkDTO = LinkDTO(id: UUID(), title: "", note: "") {
        didSet {
            if let existingEntity = getLinkEntity(id: linkDTO.id) {
                existingEntity.title = linkDTO.title
                existingEntity.note = linkDTO.note

                saveContext { error in
                    self.logger.log("While saving \(self.linkDTO) occured an unresolved error \(error.localizedDescription, privacy: .public)")
                    
                    DispatchQueue.main.async {
                        self.message = "Cannot update"
                    }
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
                }
            } else {
                let entity = TagEntity(context: persistenceContainer.viewContext)
                entity.id = UUID()
                entity.name = tagDTO.name
                entity.created = Date()
            }
            
            saveContext { error in
                self.logger.log("While saving \(String(describing: self.tagDTO)) occured an unresolved error \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.message = "Cannot save tag: \(self.tagDTO.name)"
                }
            }
            
            fetchTags()
        }
    }

    @Published var links = [LinkEntity]()
    @Published var tags = [TagEntity]()
    
    func fetchAll() {
        fetchLinks()
        fetchTags()
    }
    
    private func fetchLinks() -> Void {
        let sortDescriptors = [NSSortDescriptor(keyPath: \LinkEntity.created, ascending: false)]
        let fetchRequest = persistenceHelper.getFetchRequest(for: LinkEntity.self, entityName: "LinkEntity", sortDescriptors: sortDescriptors)
        links = persistenceHelper.fetch(fetchRequest)
    }
    
    private func fetchTags() -> Void {
        let sortDescriptors = [NSSortDescriptor(keyPath: \TagEntity.name, ascending: true)]
        let fetchRequest = persistenceHelper.getFetchRequest(for: TagEntity.self, entityName: "TagEntity", sortDescriptors: sortDescriptors)
        tags = persistenceHelper.fetch(fetchRequest)
    }
    
    func saveLinkAndTags(title: String?, url: String?, favicon: Data?, note: String?, latitude: Double, longitude: Double, locality: String?, tags: [TagEntity]) -> Void {
        let linkEntity = LinkEntity.create(title: title, url: url, favicon: favicon, note: note, latitude: self.userLatitude, longitude: self.userLongitude, locality: self.userLocality, context: self.persistenceHelper.viewContext)
        
        saveContext { error in
            self.logger.log("While saving \(linkEntity, privacy: .public) and \(tags, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                self.message = "Cannot save link: \(String(describing: title))"
            }
        }
        
        let linkDTO = LinkDTO(id: linkEntity.id ?? UUID(), title: linkEntity.title ?? "", note: linkEntity.note ?? "")
        
        for tag in tags {
            self.tagDTO = TagDTO(name: tag.name ?? "", link: linkDTO)
        }
        
        fetchAll()
    }
    
    func update(link: LinkDTO, with tags: [TagEntity]) -> Void {
        if let linkEntity = getLinkEntity(id: link.id) {
            if let tagEntites = linkEntity.tags {
                linkEntity.removeFromTags(tagEntites)
            }
            
            linkEntity.addToTags(NSSet(array: tags))
        }
        
        saveContext { error in
            self.logger.log("While removing tags from \(link) occured an unresolved error \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                self.message = "Cannot save link: \(link.title)"
            }
        }
    }
    
    func remove(tag: String, from link: LinkDTO) {
        if let linkEntity = getLinkEntity(id: link.id), let tagEntity = getTagEntity(with: tag) {
            tagEntity.removeFromLinks(linkEntity)
        }
        
        saveContext { error in
            self.logger.log("While removing \(tag) from \(link) occured an unresolved error \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                self.message = "Cannot save link = \(link.title)"
            }
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
        let fetchRequest = persistenceHelper.getFetchRequest(for: LinkEntity.self,
                                                             entityName: "LinkEntity",
                                                             predicate: NSPredicate(format: "id == %@", argumentArray: [id]))
        let fetchedLinks = persistenceHelper.fetch(fetchRequest)
        if fetchedLinks.isEmpty {
            DispatchQueue.main.async {
                self.message = "Cannot find a link with id=\(id)"
            }
        }
        return fetchedLinks.isEmpty ? nil : fetchedLinks[0]
    }
    
    private func getTagEntity(with name: String) -> TagEntity? {
        let fetchRequest = persistenceHelper.getFetchRequest(for: TagEntity.self,
                                                             entityName: "TagEntity",
                                                             predicate: NSPredicate(format: "name == %@", argumentArray: [name]))
        let fetchedTags = persistenceHelper.fetch(fetchRequest)
        if fetchedTags.isEmpty {
            DispatchQueue.main.async {
                self.message = "Cannot find a tag: \(name)"
            }
        }
        return fetchedTags.isEmpty ? nil : fetchedTags[0]
    }
    
    func delete(link: LinkEntity) -> Void {
        persistenceHelper.delete(link)
    }
    
    func delete(tag: TagEntity) -> Void {
        persistenceHelper.delete(tag)
    }
    
    func saveContext(completionHandler: ((Error) -> Void)? = nil) -> Void {
        do {
            try persistenceHelper.saveContext()
        } catch {
            completionHandler?(error)
        }
        
        DispatchQueue.main.async {
            self.fetchAll()
        }
    }
    
    // MARK: - Persistence History Request
    private func fetchUpdates(_ notification: Notification) -> Void {
        persistence.fetchUpdates(notification) { result in
            switch result {
            case .success(_):
                return
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
    private let maxNumberOfWidgetEntries = 6
    func writeWidgetEntries() {
        var widgetEntries = [WidgetEntry]()
    
        let numberOfWidgetEntries = links.count > maxNumberOfWidgetEntries ? maxNumberOfWidgetEntries : links.count
        
        // Randomly select 6 records to provide widgets per hour
        for _ in 0..<numberOfWidgetEntries {
            let entity = links[Int.random(in: 0..<links.count)]
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
