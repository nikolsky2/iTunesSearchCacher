//
//  AppManager.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import UIKit
import CoreData

protocol AppLifeCycle: class {
    func didFinishLaunching()
}

class AppManager: NSObject {
    
    private var coreDataStack: CoreDataStack!
    private var syncCoordinator: SyncCoordinator!
    private var webService: WebService!
    
    var mainContext: NSManagedObjectContext {
        return coreDataStack.mainContext
    }
    
    class func shared() -> AppManager {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        return appDelegate.appManager
    }
    
    lazy var window: UIWindow = {
        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        return window
    }()
}

extension AppManager: AppLifeCycle {
    func didFinishLaunching() {
        
        coreDataStack = CoreDataStack()
        syncCoordinator = SyncCoordinator(mainManagedObjectContext: mainContext)
        webService = WebService(persistentStoreCoordinator: coreDataStack.persistentStoreCoordinator)
        
        let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
        let navViewController = mainStoryBoard.instantiateInitialViewController()
        window.rootViewController = navViewController
        window.makeKeyAndVisible()
    }
}