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
import os
import Persistence
import SwiftUI
import CoreSpotlight

@MainActor
class LinkCollectorViewModel: NSObject, ObservableObject {
    @AppStorage("spotlightLinkIndexing") private var spotlightLinkIndexing: Bool = false
    @AppStorage("oldIndexDeleted") private var oldIndexDeleted: Bool = false
    
    static let unknown = "Unknown"
    
    private let locationManager = CLLocationManager()
    private let logger = Logger()
    private let contentsJson = "contents.json"
    
    private let persistence: Persistence
    
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
    private let searchHelper: SearchHelper
    
    private(set) var linkIndexer: LinkSpotlightDelegate?
    private var spotlightFoundLinks: [CSSearchableItem] = []
    private var linkSearchQuery: CSSearchQuery?
    
    init(persistence: Persistence) {
        self.persistence = persistence
        self.persistenceHelper = PersistenceHelper(persistence: persistence)
        
        self.searchHelper = SearchHelper(persistence: persistence)
        
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
        
        fetchAll()
        
        Task {
            if await self.searchHelper.isReady() {
                logger.log("init: oldIndexDeleted=\(self.oldIndexDeleted, privacy: .public)")
                if !self.oldIndexDeleted {
                    await self.searchHelper.refresh()
                    self.spotlightLinkIndexing = false
                    self.oldIndexDeleted = true
                }
                
                logger.log("init: spotlightIndexing=\(self.spotlightLinkIndexing, privacy: .public)")
                if !spotlightLinkIndexing {
                    await self.searchHelper.startIndexing()
                    self.indexLinks()
                    self.spotlightLinkIndexing = true
                }
                
                $searchString
                    .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
                    .sink { _ in
                        self.searchLink()
                    }
                    .store(in: &subscriptions)
            }
            
            NotificationCenter.default
                .publisher(for: UserDefaults.didChangeNotification)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.defaultsChanged()
                }
                .store(in: &subscriptions)
            
        }
        
    }
    
    // MARK: - CoreSpotlight
    @objc private func defaultsChanged() -> Void {
        if !spotlightLinkIndexing {
            toggleIndexing(linkIndexer, enabled: false)
            toggleIndexing(linkIndexer, enabled: true)
            spotlightLinkIndexing.toggle()
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
        Task {
            for link in links {
                await addToIndex(link)
            }
        }
    }
    
    private func addToIndex(_ link: LinkEntity) async -> Void {
        let attributeSet = SearchAttributeSet(uid: link.objectID.uriRepresentation().absoluteString,
                                              url: link.url,
                                              title: link.title,
                                              note: link.note,
                                              locality: link.locality)
        await searchHelper.index(attributeSet)
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
        Task {
            let items = await searchHelper.search(searchString)
            fetchLinks(items)
        }
    }
        
    private func fetchLinks(_ items: [String]) {
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
    
    private func fetch<Element>(_ type: Element.Type, _ items: [String]) -> [Element] where Element: NSManagedObject {
        return items.compactMap { (item: String) -> Element? in
            guard let url = URL(string: item) else {
                self.logger.log("url is nil for item=\(item)")
                return nil
            }
            return persistenceHelper.find(for: url) as? Element
        }
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
    
    func process(_ activity: NSUserActivity) -> Void {
        logger.log("continueActivity: \(activity)")
        guard let info = activity.userInfo, let objectIdentifier = info[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        guard let objectURI = URL(string: objectIdentifier), let entity = persistenceHelper.find(for: objectURI) else {
            logger.log("Can't find an object with objectIdentifier=\(objectIdentifier)")
            return
        }
        
        logger.log("entity = \(entity)")
        
        if let link = entity as? LinkEntity, let id = link.id {
            self.set(searchString: link.title ?? "", selected: id)
        }
    }
    
    func set(searchString: String, selected: UUID) -> Void {
        DispatchQueue.main.async {
            self.searchString = ""
            self.selected = UUID()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.searchString = searchString
            self.selected = selected
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
        let downloader = LinkCollectorDownloader(url: urlString)
        return await downloader.getUrlAndHtml()
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
    
    func findFavicon(from urlString: String) async -> Data? {
        let downloader = LinkCollectorDownloader(url: urlString)
        return await downloader.findFavicon()
    }
    
    // MARK: - Persistence
    
    func saveTag(_ tagDTO: TagDTO) -> Void {
        if let tagEntity = getTagEntity(with: tagDTO.name) {
            if let link = tagDTO.link, let linkEntity = getLinkEntity(id: link.id) {
                if let links = tagEntity.links, !links.contains(linkEntity) {
                    tagEntity.addToLinks(linkEntity)
                }
            }
        } else {
            let entity = TagEntity(context: persistenceHelper.viewContext)
            entity.id = UUID()
            entity.name = tagDTO.name
            entity.created = Date()
        }
        
        do {
            try save()
        } catch {
            logger.log("While saving \(String(describing: tagDTO)) occured an unresolved error \(error.localizedDescription, privacy: .public)")
            self.message = "Cannot save tag: \( tagDTO.name)"
        }
    }

    @Published var links = [LinkEntity]()
    @Published var tags = [TagEntity]()
    
    func fetchAll() {
        searchString = ""
        fetchLinks()
        fetchTags()
    }
    
    var firstDate: Date {
        return links.last?.created ?? Date()
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
        
        do {
            try save()
        } catch {
            logger.log("While saving \(linkEntity, privacy: .public) and \(tags, privacy: .public) occured an unresolved error \(error.localizedDescription, privacy: .public)")
            self.message = "Cannot save link: \(String(describing: title))"
        }
        
        let linkDTO = LinkDTO(id: linkEntity.id ?? UUID(), title: linkEntity.title ?? "", note: linkEntity.note ?? "")
        
        for tag in tags {
            saveTag(TagDTO(name: tag.name ?? "", link: linkDTO))
        }
        
        fetchAll()
    }
    
    func update(link: LinkDTO, with tags: [TagEntity]) -> Void {
        guard let linkEntity = getLinkEntity(id: link.id) else {
            logger.log("Cannot find an existing link: \(link, privacy: .public)")
            return
        }
        
       
            linkEntity.title = link.title
            linkEntity.note = link.note
            
            if let tagEntites = linkEntity.tags {
                linkEntity.removeFromTags(tagEntites)
            }
            linkEntity.addToTags(NSSet(array: tags))
            
            do {
                try save()
            } catch {
                logger.log("While updating \(link) with \(tags) occured an unresolved error \(error.localizedDescription, privacy: .public)")
                self.message = "Cannot update link: \(link)"
            }
            
            fetchAll()
        
    }
    
    func remove(tag: String, from link: LinkDTO) {
        if let linkEntity = getLinkEntity(id: link.id), let tagEntity = getTagEntity(with: tag) {
            tagEntity.removeFromLinks(linkEntity)
        }
        
        do {
            try save()
        } catch {
            logger.log("While removing \(tag) from \(link) occured an unresolved error \(error.localizedDescription, privacy: .public)")
            self.message = "Cannot save link = \(link.title)"
        }
        
        fetchAll()
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
    
    func save() throws -> Void {
        Task {
            try await persistenceHelper.save()
        }
    }
    
    // MARK: - Persistence History Request
    private func fetchUpdates(_ notification: Notification) -> Void {
        Task {
            do {
                let objectIDs = try await persistence.fetchUpdates()
                for objectId in objectIDs {
                    await addToIndex(objectId)
                }
            } catch {
                logger.log("Error while updating history: notification=\(notification)\n\(error.localizedDescription, privacy: .public)\n\(Thread.callStackSymbols, privacy: .public)")
            }
        }
    }
    
    private func addToIndex(_ objectID: NSManagedObjectID) async -> Void {
        guard let linkEntity = persistenceHelper.find(with: objectID) as? LinkEntity else {
            remove(with: objectID.uriRepresentation().absoluteString)
            logger.log("Removed from index: \(objectID)")
            return
        }
        
        await addToIndex(linkEntity)
    }
    
    private func remove(with identifier: String) {
        guard let linkIndexer = linkIndexer, let indexName = linkIndexer.indexName() else { return }
        
        CSSearchableIndex(name: indexName).deleteSearchableItems(withIdentifiers: [identifier]) { error in
            self.logger.log("Can't delete an item with identifier=\(identifier, privacy: .public)")
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
    
    // MARK: - Export links as a bookmark file
    private let bookmarksFileName = "bookmarks.html"
    
    func generateBookmarkFile(_ links: [LinkEntity]) -> URL {
        let bookmarkGenerator = BookmarkGenerator(links: links)
        let url = URL.documentsDirectory.appending(path: bookmarksFileName)
        do {
            try bookmarkGenerator.getBookmarkFile()
                .write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.log("Error while writing bookmark file: \(error.localizedDescription, privacy: .public)")
        }
        return url
    }
    
}

extension LinkCollectorViewModel: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      guard let location = locations.last else { return }
      userLatitude = location.coordinate.latitude
      userLongitude = location.coordinate.longitude
    }
}
