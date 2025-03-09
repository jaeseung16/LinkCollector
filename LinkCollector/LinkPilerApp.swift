//
//  LinkPilerApp.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 3/9/25.
//

import SwiftUI
import Persistence

@main
struct LinkPilerApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #else
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(appDelegate.viewModel)
            #else
            ContentView()
                .environmentObject(appDelegate.viewModel)
                .onOpenURL { url in
                    appDelegate.viewModel.set(searchString: url.query?.removingPercentEncoding ?? "",
                                       selected: UUID(uuidString: url.lastPathComponent)!)
                }
            #endif
        }
    }
}
