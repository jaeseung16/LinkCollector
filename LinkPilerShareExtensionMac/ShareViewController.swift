//
//  ShareViewController.swift
//  LinkPilerShareExtensionMac
//
//  Created by Jae Seung Lee on 3/25/25.
//

import Cocoa
import os
import FaviconFinder
import CoreData
import Persistence
import MapKit

// One-time reset of this extension's local store.
//
// The store had been mirroring correctly until 2026-05-17, when its imports stopped and every
// export started failing with CKError.partialFailure -- 1000+ records re-offered with change
// tags that the server had long since moved past, which fails the whole batch including the
// link the user just shared. Nothing recovers from that state on its own and no API resets the
// mirroring metadata, so the store has to go. NSPersistentCloudKitContainer rebuilds it and
// re-imports the library from iCloud on the next launch.
//
// Anything in the old store that never exported is discarded, by design: it is the only data
// there that is not already in iCloud, and there is no way to show the user what it was.
// See docs/worklog/2026-09-08-share-extension-crash.md.
private enum ShareExtensionStoreReset {
    private static let logger = Logger()
    private static let defaultsKey = "shareExtensionStoreResetVersion"
    private static let version = 1

    // Must run before anything opens the store, i.e. before Persistence is constructed.
    static func runIfNeeded() -> Void {
        guard UserDefaults.standard.integer(forKey: defaultsKey) < version else {
            return
        }

        let directory = NSPersistentContainer.defaultDirectoryURL()
        let name = LinkPilerConstants.appPathComponent.rawValue
        // "\(name)" is the directory Persistence keeps its history token in; a token pointing
        // into a store that no longer exists would break the purge on the next launch.
        let items = ["\(name).sqlite", "\(name).sqlite-wal", "\(name).sqlite-shm",
                     ".\(name)_SUPPORT", "\(name)_ckAssets", name]

        var removedEverything = true
        for item in items {
            let url = directory.appendingPathComponent(item)
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            do {
                try FileManager.default.removeItem(at: url)
                logger.log("Removed \(item, privacy: .public)")
            } catch {
                removedEverything = false
                logger.error("Could not remove \(item, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        // Leave the marker unset on failure so the next launch tries again; a half-deleted
        // store is worse than one that is still wedged.
        if removedEverything {
            UserDefaults.standard.set(version, forKey: defaultsKey)
        }
    }
}

class ShareViewController: NSViewController {
    private let logger = Logger()
    
    private lazy var persistenceController: Persistence = {
        ShareExtensionStoreReset.runIfNeeded()
        return Persistence(name: LinkPilerConstants.appPathComponent.rawValue, identifier: LinkPilerConstants.containerIdentifier.rawValue)
    }()
    
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    private let contextName = "share extension"
    private let unknown = "Unknown"
    
    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var locationTextField: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    private var posted: Date?
    private var linkEntity: LinkEntity?
    private var favicon: Data?
    
    private let locationManager = CLLocationManager()
    private var location: CLLocation? {
        didSet {
            locationManager.stopUpdatingLocation()
            Task {
                locality = await lookUpCurrentLocation()
            }
        }
    }
    
    private var locality: String? {
        didSet {
            DispatchQueue.main.async {
                self.locationTextField.stringValue = self.locality ?? self.unknown
            }
        }
    }
    
    private func lookUpCurrentLocation() {
        Task {
            self.locality = await lookUpCurrentLocation()
        }
    }

    private func lookUpCurrentLocation() async -> String {
        guard let lastLocation = locationManager.location,
              let request = MKReverseGeocodingRequest(location: lastLocation) else {
            return unknown
        }

        do {
            let mapItems = try await request.mapItems
            return mapItems.first?.addressRepresentations?.cityName ?? unknown
        } catch {
            logger.log("Cannot find any descriptions for the location: \(lastLocation)")
            return unknown
        }
    }
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("ShareViewController")
    }
    
    override func viewWillAppear() {
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }

    override func loadView() {
        super.loadView()
    
        self.progressIndicator.stopAnimation(nil)
        if let extensionContext = extensionContext, !extensionContext.inputItems.isEmpty {
            for inputItem in extensionContext.inputItems {
                if let item = inputItem as? NSExtensionItem {
                    accessWebpageProperties(extensionItem: item)
                }
            }
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(processNotification),
                                               name: .NSPersistentStoreRemoteChange,
                                               object: persistenceController.container.persistentStoreCoordinator)
    }
    
    // Core Data posts .NSPersistentStoreRemoteChange on its own private queue. This class is
    // @MainActor by inheritance, so under Swift 6 the @objc thunk asserts main-actor isolation
    // before entering the body and traps. Take the callback nonisolated and hop explicitly.
    @objc private nonisolated func processNotification(_ notification: Notification) -> Void {
        Task { @MainActor in
            self.handleRemoteChange()
        }
    }

    private func handleRemoteChange() -> Void {
        guard let posted = posted else {
            return
        }

        let fetchHistoryRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: posted)
        let context = persistenceController.container.newBackgroundContext()

        // execute() has to run on the context's own queue.
        var history: [NSPersistentHistoryTransaction]?
        context.performAndWait {
            history = (try? context.execute(fetchHistoryRequest) as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryTransaction]
        }

        guard let history else {
            showAlertAndTerminate()
            return
        }

        for transaction in history {
            if transaction.timestamp > posted && transaction.contextName == contextName {
                guard let changes = transaction.changes else { continue }

                for change in changes {
                    if change.changeType == .insert {
                        if let link = self.linkEntity, change.changedObjectID == link.objectID {
                            self.progressIndicator.stopAnimation(nil)

                            if self.extensionContext != nil {
                                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                            }

                            return
                        }
                    }
                }
            }
        }
    }

    @IBAction func send(_ sender: AnyObject?) {
        DispatchQueue.main.async {
            self.progressIndicator.startAnimation(nil)
        }
        
        var favicon: Data?
        if let url = URL(string: urlTextField.stringValue) {
            var urlComponents = URLComponents()
            urlComponents.scheme = url.scheme
            urlComponents.host = url.host
            urlComponents.path = "/favicon.ico"
            
            if let faviconURL = urlComponents.url {
                favicon = try? Data(contentsOf: faviconURL)
            }
        }
        
        posted = Date()
        linkEntity = LinkEntity.create(title: titleTextField.stringValue,
                                       url: urlTextField.stringValue,
                                       favicon: favicon,
                                       note: "",
                                       latitude: location?.coordinate.latitude ?? 0.0,
                                       longitude: location?.coordinate.latitude ?? 0.0,
                                       locality: self.locality,
                                       context: persistenceController.container.viewContext)
        
        save(with: contextName)
        
        // Terminate after 10 sec
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.showAlertAndTerminate()
        }
    }
    
    private func showAlertAndTerminate() -> Void {
        self.progressIndicator.stopAnimation(nil)
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Alert"
        alert.informativeText = "Cannot confirm whether the post is saved. You may want to try it again."
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .OK {
            if self.extensionContext != nil {
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    private func save(with contextName: String) -> Void {
        viewContext.name = contextName
        do {
            try viewContext.save()
        } catch {
            self.logger.log("Cannot save \(self.linkEntity, privacy: .public)")
        }
        viewContext.name = nil
    }
    
    @IBAction func cancel(_ sender: AnyObject?) {
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func accessWebpageProperties(extensionItem: NSExtensionItem) {
        if let userInfo = extensionItem.userInfo, let attachments = userInfo[NSExtensionItemAttachmentsKey] as? [NSItemProvider] {
            for attachment in attachments {
                self.logger.log("registeredTypeIdentifiers = \(attachment.registeredTypeIdentifiers, privacy: .public)")
                
                for typeIdentifier in attachment.registeredTypeIdentifiers {
                    switch TypeIdentifier.init(rawValue: typeIdentifier) {
                    case .propertyList:
                        Task {
                            do {
                                let item = try await attachment.loadItem(forTypeIdentifier: TypeIdentifier.propertyList.rawValue, options: nil)
                                
                                if let dictionary = item as? NSDictionary,
                                   let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                                    self.update(with: results)
                                }
                            } catch {
                                self.showAlert(attachment: attachment, error: error)
                            }
                        }
                    case .publicURL:
                        Task {
                            do {
                                let item = try await attachment.loadItem(forTypeIdentifier: TypeIdentifier.publicURL.rawValue, options: nil)
                                if let data = item as? Data,
                                   let urlString = String(data: data, encoding: .utf8),
                                   let url = URL(string: urlString) {
                                    self.update(with: url)
                                }
                            } catch {
                                self.showAlert(attachment: attachment, error: error)
                            }
                        }
                    case .plainText:
                        Task {
                            do {
                                let item = try await attachment.loadItem(forTypeIdentifier: TypeIdentifier.plainText.rawValue, options: nil)
                                
                                if let text = item as? String {
                                    self.update(with: text)
                                }
                            } catch {
                                self.showAlert(attachment: attachment, error: error)
                            }
                        }
                    case .none:
                        self.logger.log("Ignore typeIdentifier = \(typeIdentifier, privacy: .public)")
                        continue
                    }
                }
            }
        }
    }
    
    private func update(with results: NSDictionary) {
        urlTextField.stringValue = results["URL"] as? String ?? "http://"
        titleTextField.stringValue = results["title"] as? String ?? "Enter title"
    }
    
    private func update(with publicURL: URL) {
        DispatchQueue.main.async {
            self.urlTextField.stringValue = publicURL.absoluteString
            self.progressIndicator.startAnimation(nil)
        }
        
        process(urlString: publicURL.absoluteString) { url, result in
            DispatchQueue.main.async {
                self.titleTextField.stringValue = result ?? "Enter title"
                self.progressIndicator.stopAnimation(nil)
                
                if let url = url {
                    self.findFavicon(url: url) { data, error in
                        guard let data = data else {
                            self.logger.log("Can't download favicon from \(url, privacy: .public): \(String(describing: error?.localizedDescription), privacy: .public))")
                            return
                        }
                        self.favicon = data
                    }
                }
            }
        }
    }
    
    private func update(with plainText: String) {
        DispatchQueue.main.async {
            self.urlTextField.stringValue = plainText
            self.progressIndicator.startAnimation(nil)
        }
        
        process(urlString: plainText) { url, result in
            DispatchQueue.main.async {
                self.titleTextField.stringValue = result ?? "Enter title"
                self.progressIndicator.stopAnimation(nil)
                
                if let url = url {
                    self.findFavicon(url: url) { data, error in
                        guard let data = data else {
                            self.logger.log("Can't download favicon from \(url, privacy: .public): \(String(describing: error?.localizedDescription), privacy: .public))")
                            return
                        }
                        self.favicon = data
                    }
                }
            }
        }
    }
    
    private func process(urlString: String, completionHandler: @escaping (_ url: URL?, _ result: String?) -> Void) -> Void {
        let (url, html) = getURLAndHTML(from: urlString)
        
        guard let url = url, let html = html else {
            completionHandler(nil, nil)
            return
        }
        
        Task {
            let htmlParser = HTMLParser()
            let result = await htmlParser.parse(url: url, html: html)
            completionHandler(url, result)
        }
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
            return (url, try? String(contentsOf: url, encoding: .utf8))
        } else {
            return (nil, nil)
        }
    }
    
    private func isValid(urlString: String) -> Bool {
        guard let urlComponent = URLComponents(string: urlString), let scheme = urlComponent.scheme else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
    
    private func findFavicon(url: URL, completionHandler: @escaping (_ favicon: Data?, _ error: Error?) -> Void) {
        Task {
            do {
                let favicon = try await FaviconFinder(url: url, configuration: .init(preferredSource: .ico, acceptHeaderImage: true))
                    .fetchFaviconURLs()
                    .download()
                    .largest()
                DispatchQueue.main.async {
                    completionHandler(favicon.image?.data, nil)
                }
            } catch {
                self.logger.log("Cannot find favicon from \(url, privacy: .public)")
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
            }
        }
    }
    
    private func showAlert(attachment: NSItemProvider, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Link Collector"
        alert.informativeText = "Cannot read the webpage's properties"
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .OK {
            logger.log("Cannot read properties: attachment = \(attachment), \(error)")
        }
    }
}

extension ShareViewController: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.log("didFailWithError: \(error)")
    }
}
