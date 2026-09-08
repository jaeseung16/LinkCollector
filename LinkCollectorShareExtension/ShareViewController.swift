//
//  ShareViewController.swift
//  LinkCollectorShareExtension
//
//  Created by Jae Seung Lee on 8/8/21.
//

import UIKit
import Social
import CoreData
import MapKit
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

        let context = persistenceController.container.newBackgroundContext()

        // execute() has to run on the context's own queue, and the request is built in there
        // too: it is not Sendable, and performAndWait's closure is.
        let history = context.performAndWait {
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: posted)
            return (try? context.execute(request) as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryTransaction]
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
                            self.activityIndicator.stopAnimating()

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
        update(with: publicURL.absoluteString)
    }

    private func update(with plainText: String) {
        urlLabel.text = plainText
        activityIndicator.startAnimating()

        // LinkCollectorDownloader is an actor, so the download runs off the main actor and this
        // resumes back on it. Doing it inline blocked the share sheet for the whole fetch, and
        // for up to three of them on the https -> http retry path.
        Task {
            let (url, html) = await LinkCollectorDownloader(url: plainText).getUrlAndHtml()

            var title: String?
            if let url = url, let html = html {
                title = await HTMLParser().parse(url: url, html: html)
            }

            titleTextField.text = title ?? "Enter title"
            activityIndicator.stopAnimating()

            if let url = url {
                favicon = await LinkCollectorDownloader(url: url.absoluteString).findFavicon()
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
                                       longitude: location?.coordinate.longitude ?? 0.0,
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
