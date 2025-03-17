//
//  AppDelegate.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/15/20.
//

import UIKit
import CoreData
@preconcurrency import UserNotifications
import CloudKit
import os
import Persistence
import CoreSpotlight

@MainActor
class AppDelegate: NSObject {
    private let logger = Logger()
    
    private let subscriptionID = "link-updated"
    private let didCreateLinkSubscription = "didCreateLinkSubscription"
    private let recordType = "CD_LinkEntity"
    private let recordValueKey = "CD_title"
    
    private var tokenCache = [NotificationTokenType: CKServerChangeToken]()
    
    private let databaseOperationHelper = DatabaseOperationHelper(appName: LinkPilerConstants.appPathComponent.rawValue)
    
    private var database: CKDatabase {
        CKContainer(identifier: LinkPilerConstants.containerIdentifier.rawValue).privateCloudDatabase
    }
    
    let persistence: Persistence
    let viewModel: LinkCollectorViewModel
    
    override init() {
        self.persistence = Persistence(name: LinkPilerConstants.appPathComponent.rawValue, identifier: LinkPilerConstants.containerIdentifier.rawValue)
        self.viewModel = LinkCollectorViewModel(persistence: persistence)
        
        super.init()
    }
    
    private func registerForPushNotifications() {
        Task {
            let notificationCenter = UNUserNotificationCenter.current()
            do {
                let authroized = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                logger.info("registerForPushNotifications \(authroized)")
                if authroized {
                    getNotificationSettings()
                }
            } catch {
                logger.info("Failed to register for push notifications: \(error)")
            }
        }
    }

    private func getNotificationSettings() {
        Task {
            let notificationCenter = UNUserNotificationCenter.current()
            let settings = await notificationCenter.notificationSettings()
            if settings.authorizationStatus == .authorized {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    private func subscribe() {
        guard !UserDefaults.standard.bool(forKey: didCreateLinkSubscription) else {
            logger.log("already true: didCreateLinkSubscription=\(UserDefaults.standard.bool(forKey: self.didCreateLinkSubscription))")
            return
        }
        
        let subscriber = Subscriber(database: database, subscriptionID: subscriptionID, recordType: recordType)
        // TODO: - Not working with Swift 6
        subscriber.subscribe()
    }

    private func processRemoteNotification() {
        databaseOperationHelper.addDatabaseChangesOperation(database: database) { result in
            switch result {
            case .success(let record):
                self.processRecord(record)
            case .failure(let error):
                self.logger.log("Failed to process remote notification: error=\(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func processRecord(_ record: CKRecord) {
        guard record.recordType == recordType else {
            return
        }
        
        guard let title = record.value(forKey: recordValueKey) as? String else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = LinkPilerConstants.appName.rawValue
        content.body = title
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        logger.log("Processed \(record)")
    }
}

extension AppDelegate: UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       
        UNUserNotificationCenter.current().delegate = self
        
        registerForPushNotifications()
        
        // TODO: - Remove or comment out after testing
        //UserDefaults.standard.setValue(false, forKey: didCreateLinkSubscription)
        
        subscribe()

        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        logger.log("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.log("Failed to register: \(String(describing: error))")
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            logger.log("notification=failed")
            completionHandler(.failed)
            return
        }
        logger.log("notification=\(String(describing: notification))")
        if !notification.isPruned && notification.notificationType == .database {
            if let databaseNotification = notification as? CKDatabaseNotification, databaseNotification.subscriptionID == subscriptionID {
                logger.log("databaseNotification=\(String(describing: databaseNotification.subscriptionID))")
                processRemoteNotification()
            }
        }
        
        completionHandler(.newData)
    }
       
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void) -> Bool {
        guard let info = userActivity.userInfo, let _ = info[CSSearchableItemActivityIdentifier] as? String else {
            return false
        }
        
        viewModel.process(userActivity)
        return true
    }
}

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        logger.info("userNotificationCenter: notification=\(notification)")
        return [.banner, .sound]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        return
    }
}
