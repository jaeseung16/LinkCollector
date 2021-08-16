//
//  ShareViewController.swift
//  LinkCollectorShareExtension
//
//  Created by Jae Seung Lee on 8/8/21.
//

import UIKit
import Social
import CoreLocation

class ShareViewController: UIViewController {

    private let persistenceController = PersistenceController.shared
    
    private let htmlParser = HTMLParser()
    private let locationManager = CLLocationManager()
    private var location: CLLocation?
    
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var locationTextField: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        locationManager.delegate = self
        locationManager.requestLocation()
    }
    
    override func viewDidLoad() {
        if let extensionContext = extensionContext, !extensionContext.inputItems.isEmpty {
            print("extensionContext.inputItems.count = \(extensionContext.inputItems.count)")
            for inputItem in extensionContext.inputItems {
                if let item = inputItem as? NSExtensionItem {
                    accessWebpageProperties(extensionItem: item)
                }
            }
        }
    }
    
    private func accessWebpageProperties(extensionItem: NSExtensionItem) {
        if let userInfo = extensionItem.userInfo, let attachments = userInfo[NSExtensionItemAttachmentsKey] as? [NSItemProvider] {
            for attachment in attachments {
                print("registeredTypeIdentifiers = \(attachment.registeredTypeIdentifiers)")
                
                for typeIdentifier in attachment.registeredTypeIdentifiers {
                    switch TypeIdentifier.init(rawValue: typeIdentifier) {
                    case .propertyList:
                        attachment.loadItem(forTypeIdentifier: TypeIdentifier.propertyList.rawValue, options: nil) { item, error in
                            guard error == nil else {
                                DispatchQueue.main.async {
                                    self.showAlert(attachment: attachment, error: error!)
                                }
                                return
                            }
                            
                            if let dictionary = item as? NSDictionary,
                               let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                                DispatchQueue.main.async {
                                    self.update(with: results)
                                }
                            }
                        }
                    case .publicURL:
                        attachment.loadItem(forTypeIdentifier: TypeIdentifier.publicURL.rawValue, options: nil) { item, error in
                            guard error == nil else {
                                DispatchQueue.main.async {
                                    self.showAlert(attachment: attachment, error: error!)
                                }
                                return
                            }
                            
                            if let publicURL = item as? URL {
                                self.update(with: publicURL)
                            }
                        }
                    case .plainText:
                        attachment.loadItem(forTypeIdentifier: TypeIdentifier.plainText.rawValue, options: nil) { item, error in
                            guard error == nil else {
                                DispatchQueue.main.async {
                                    self.showAlert(attachment: attachment, error: error!)
                                }
                                return
                            }
                            
                            if let text = item as? String {
                                self.update(with: text)
                            }
                        }
                    case .none:
                        print("Ignore typeIdentifier = \(typeIdentifier)")
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
        
        lookUpCurrentLocation() { place in
            if place == nil {
                self.locationTextField.text = "Unknown"
            } else {
                self.locationTextField.text = place!.locality
            }
        }
    }
    
    private func update(with publicURL: URL) {
        DispatchQueue.main.async {
            self.urlLabel.text = publicURL.absoluteString
        }
        
        htmlParser.parse(url: publicURL) { result in
            DispatchQueue.main.async {
                self.titleTextField.text = result != "" ? result : "Enter title"
            }
        }
        
        lookUpCurrentLocation() { place in
            DispatchQueue.main.async {
                if place == nil {
                    self.locationTextField.text = "Unknown"
                } else {
                    self.locationTextField.text = place!.locality
                }
            }
        }
    }
    
    private func update(with plainText: String) {
        DispatchQueue.main.async {
            self.urlLabel.text = plainText
        }
        
        if let htmlURL = URL(string: plainText) {
            htmlParser.parse(url: htmlURL) { result in
                DispatchQueue.main.async {
                    self.titleTextField.text = result
                }
            }
        } else {
            DispatchQueue.main.async {
                self.titleTextField.text = "Enter title"
            }
        }
        
        lookUpCurrentLocation() { place in
            DispatchQueue.main.async {
                if place == nil {
                    self.locationTextField.text = "Unknown"
                } else {
                    self.locationTextField.text = place!.locality
                }
            }
        }
    }
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @IBAction func post(_ sender: UIBarButtonItem) {
        LinkEntity.create(title: titleTextField.text,
                          url: urlLabel.text,
                          latitude: location != nil ? location!.coordinate.latitude : 0.0,
                          longitude: location != nil ? location!.coordinate.latitude : 0.0,
                          context: persistenceController.container.viewContext)
     
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func lookUpCurrentLocation(completionHandler: @escaping (CLPlacemark?) -> Void) {
        if let lastLocation = locationManager.location {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(lastLocation) { (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?[0]
                    completionHandler(firstLocation)
                } else {
                    completionHandler(nil)
                }
            }
        } else {
            completionHandler(nil)
        }
    }
    
}

extension ShareViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("didFailWithError: \(error)")
    }
}
