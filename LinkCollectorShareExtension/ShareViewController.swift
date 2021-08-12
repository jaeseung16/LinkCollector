//
//  ShareViewController.swift
//  LinkCollectorShareExtension
//
//  Created by Jae Seung Lee on 8/8/21.
//

import UIKit
import Social

class ShareViewController: UIViewController {

    private let locationManager = CLLocationManager()
    private var location: CLLocation?
    
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var locationTextField: UILabel!
    
    
    /*
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        
        print("\(self.textView.text)")
        
        
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
    */
    
    override func viewWillAppear(_ animated: Bool) {
        locationManager.delegate = self
        locationManager.requestLocation()
    }
    
    override func viewDidLoad() {
        if let extensionContext = extensionContext, !extensionContext.inputItems.isEmpty {
            print("extensionContext.inputItems.count = \(extensionContext.inputItems.count)")
            for inputItem in extensionContext.inputItems {
                //print("inputItem = \(inputItem)")
                if let item = inputItem as? NSExtensionItem {
                    //print("item = \(item)")
                    accessWebpageProperties(extensionItem: item)
                }
            }
        }
    }
    
    private func accessWebpageProperties(extensionItem: NSExtensionItem) {
        let propertyList = "com.apple.property-list" //String(kUTTypePropertyList)

        if let userInfo = extensionItem.userInfo, let attachments = userInfo[NSExtensionItemAttachmentsKey] as? [NSItemProvider] {
            
            print("attachments = \(attachments)")
            for attachment in attachments {
                attachment.loadItem(forTypeIdentifier: propertyList, options: nil) { item, error in
                    print("item = \(item), error = \(error)")
                    if let dictionary = item as? NSDictionary,
                       let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                        print("results = \(results)")
                        
                        DispatchQueue.main.async {
                            self.urlLabel.text = results["URL"] as? String ?? "http://"
                            self.titleTextField.text = results["title"] as? String ?? "Enter title"
                            
                            self.lookUpCurrentLocation() { place in
                                if place == nil {
                                    self.locationTextField.text = "Unknown"
                                } else {
                                    print("\(place!.name) \(place!.subLocality) \(place!.locality) \(place!.postalCode)")
                                    self.locationTextField.text = place!.locality
                                }
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    
    @IBAction func cancel(_ sender: UIButton) {
        print("cancel")
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @IBAction func post(_ sender: UIButton) {
        print("URL = \(urlLabel.text)")
        print("titel = \(titleTextField.text)")
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func lookUpCurrentLocation(completionHandler: @escaping (CLPlacemark?) -> Void) {
        // Use the last reported location.
        if let lastLocation = self.locationManager.location {
            let geocoder = CLGeocoder()
            
            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(lastLocation, completionHandler: { (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?[0]
                    completionHandler(firstLocation)
                }
                else {
                    completionHandler(nil)
                }
            })
        }
        else {
            completionHandler(nil)
        }
    }
    
}

extension ShareViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("didUpdateLocations")
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError: \(error)")
    }
}
