//
//  AppDelegate.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var appManager = AppManager()
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        appManager.didFinishLaunching()
        
        return true
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        appManager.mainContext.refreshAllObjects()
    }
    
    func applicationDidReceiveMemoryWarning(application: UIApplication) {
        appManager.mainContext.refreshAllObjects()
    }
}
