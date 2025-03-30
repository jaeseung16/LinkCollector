//
//  ShareViewController.swift
//  LinkPilerShareExtensionMac
//
//  Created by Jae Seung Lee on 3/25/25.
//

@preconcurrency import Cocoa
import os
@preconcurrency import FaviconFinder
import CoreData
import Persistence
import CoreLocation

class ShareViewController: NSViewController {
    private let logger = Logger()
    
    private let persistenceController = Persistence(name: LinkPilerConstants.appPathComponent.rawValue, identifier: LinkPilerConstants.containerIdentifier.rawValue)
    
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
    
    private let htmlParser = HTMLParser()
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
    
    private func lookUpCurrentLocation() async -> String {
        if let lastLocation = location {
            do {
                let geocoder = CLGeocoder()
                let placemarks = try await geocoder.reverseGeocodeLocation(lastLocation)
                return placemarks.isEmpty ? unknown : placemarks[0].locality ?? unknown
            } catch {
                logger.log("Cannot find any descriptions for the location: \(lastLocation)")
                return unknown
            }
        } else {
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
    
    @objc private func processNotification(_ notification: Notification) -> Void {
        guard let posted = posted else {
            return
        }
        
        let fetchHistoryRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: posted)
        let context = persistenceController.container.newBackgroundContext()
        
        guard let historyResult = try? context.execute(fetchHistoryRequest) as? NSPersistentHistoryResult,
              let history = historyResult.result as? [NSPersistentHistoryTransaction] else {
            DispatchQueue.main.async {
                self.showAlertAndTerminate()
            }
            return
        }
        
        for transaction in history {
            if transaction.timestamp > posted && transaction.contextName == contextName {
                guard let changes = transaction.changes else { continue }
                
                for change in changes {
                    if change.changeType == .insert {
                        if let link = self.linkEntity, change.changedObjectID == link.objectID {
                            DispatchQueue.main.async {
                                self.progressIndicator.stopAnimation(nil)
                            }
                            
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
