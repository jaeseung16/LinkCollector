//
//  ShareViewController.swift
//  LinkCollectorShareExtension
//
//  Created by Jae Seung Lee on 8/8/21.
//

import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {

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
        let propertyList = String(kUTTypePropertyList)

        if let userInfo = extensionItem.userInfo, let attachments = userInfo[NSExtensionItemAttachmentsKey] as? [NSItemProvider] {
            
            print("attachments = \(attachments)")
            for attachment in attachments {
                attachment.loadItem(forTypeIdentifier: propertyList, options: nil) { item, error in
                    print("item = \(item), error = \(error)")
                    if let dictionary = item as? NSDictionary,
                       let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                        print("results = \(results)")
                    }
                }
            }
            
        }
        
    }
}
