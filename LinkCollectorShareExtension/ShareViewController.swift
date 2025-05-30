//
//  ShareViewController.swift
//  LinkCollectorShareExtension
//
//  Created by Jae Seung Lee on 8/8/21.
//

@preconcurrency import UIKit
import Social
import CoreLocation
import CoreData
@preconcurrency import FaviconFinder
import Persistence
import os

class ShareViewController: UIViewController {
    private let logger = Logger()

    private let persistenceController = Persistence(name: LinkPilerConstants.appPathComponent.rawValue, identifier: LinkPilerConstants.containerIdentifier.rawValue)
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    private let contextName = "share extension"
    private let unknown = "Unknown"
    
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
                self.locationTextField.text = self.locality ?? self.unknown
            }
        }
    }
    
    private var posted: Date?
    private var linkEntity: LinkEntity?
    private var favicon: Data?
    
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var locationTextField: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewWillAppear(_ animated: Bool) {
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }
    
    override func viewDidLoad() {
        self.activityIndicator.stopAnimating()
        
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
    
    private func showAlertAndTerminate() -> Void {
        self.activityIndicator.stopAnimating()
        
        let alert = UIAlertController(title: "Alert", message: "Cannot confirm whether the post is saved. You may want to try it again.", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .default) { _ in
                if self.extensionContext != nil {
                    self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                }
        })
        
        self.present(alert, animated: true)
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
                                self.activityIndicator.stopAnimating()
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
                                
                                if let publicURL = item as? URL {
                                    self.update(with: publicURL)
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
    
    private func showAlert(attachment: NSItemProvider, error: Error) {
        let alert = UIAlertController(title: "Link Collector", message: "Cannot read the webpage's properties", preferredStyle: .alert)
        let action = UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default) { _ in
            NSLog("Cannot read properties: attachment = \(attachment), \(error)")
        }
        
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    private func update(with results: NSDictionary) {
        urlLabel.text = results["URL"] as? String ?? "http://"
        titleTextField.text = results["title"] as? String ?? "Enter title"
    }
    
    private func update(with publicURL: URL) {
        DispatchQueue.main.async {
            self.urlLabel.text = publicURL.absoluteString
            self.activityIndicator.startAnimating()
        }
        
        process(urlString: publicURL.absoluteString) { url, result in
            DispatchQueue.main.async {
                self.titleTextField.text = result ?? "Enter title"
                self.activityIndicator.stopAnimating()
                
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
            self.urlLabel.text = plainText
            self.activityIndicator.startAnimating()
        }
        
        process(urlString: plainText) { url, result in
            DispatchQueue.main.async {
                self.titleTextField.text = result ?? "Enter title"
                self.activityIndicator.stopAnimating()
                
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
    
    private func isValid(urlString: String) -> Bool {
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
            return (url, try? String(contentsOf: url, encoding: .utf8))
        } else {
            return (nil, nil)
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
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @IBAction func post(_ sender: UIBarButtonItem) {
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
        }
        
        var favicon: Data?
        if let urlString = urlLabel.text, let url = URL(string: urlString) {
            var urlComponents = URLComponents()
            urlComponents.scheme = url.scheme
            urlComponents.host = url.host
            urlComponents.path = "/favicon.ico"
            
            if let faviconURL = urlComponents.url {
                favicon = try? Data(contentsOf: faviconURL)
            }
        }
        
        posted = Date()
        linkEntity = LinkEntity.create(title: titleTextField.text,
                                       url: urlLabel.text,
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
    
    private func save(with contextName: String) -> Void {
        viewContext.name = contextName
        do {
            try viewContext.save()
        } catch {
            self.logger.log("Cannot save \(self.linkEntity, privacy: .public)")
        }
        viewContext.name = nil
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
