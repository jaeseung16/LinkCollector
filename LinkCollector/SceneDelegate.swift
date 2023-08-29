//
//  SceneDelegate.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/15/20.
//

import UIKit
import SwiftUI
import Persistence
import CoreSpotlight

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    let persistence: Persistence
    let viewModel: LinkCollectorViewModel
    
    override init() {
        self.persistence = Persistence(name: LinkPilerConstants.appPathComponent.rawValue, identifier: LinkPilerConstants.containerIdentifier.rawValue)
        self.viewModel = LinkCollectorViewModel(persistence: persistence)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        if let urlContext = connectionOptions.urlContexts.first {
            if urlContext.url.scheme == LinkPilerConstants.widgetURLScheme.rawValue {
                viewModel.selected = UUID(uuidString: urlContext.url.lastPathComponent)!
            }
        }
        
        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let contentView = ContentView()
            .environmentObject(viewModel)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        viewModel.saveContext() { _ in
            //
        }
        viewModel.writeWidgetEntries()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let context = URLContexts.first else {
            return
        }
        viewModel.selected = UUID(uuidString: context.url.lastPathComponent)!
        viewModel.searchString = context.url.query?.removingPercentEncoding ?? ""
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let info = userActivity.userInfo, let _ = info[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        
        viewModel.continueActivity(userActivity) { entity in
            if let link = entity as? LinkEntity, let id = link.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.viewModel.searchString = link.title ?? ""
                    self.viewModel.selected = id
                }
            }
        }
        
    }

}

