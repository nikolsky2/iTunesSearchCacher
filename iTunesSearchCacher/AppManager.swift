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
    private var downloadManager: DownloadMangerActiveObject!
    
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
    
    func fetchDataAgain() {
        downloadManager.performFetch()
    }
}

extension AppManager: AppLifeCycle {
    func didFinishLaunching() {
        
        let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
        let navViewController = mainStoryBoard.instantiateInitialViewController()
        window.rootViewController = navViewController
        window.makeKeyAndVisible()
        
        coreDataStack = CoreDataStack()
        downloadManager = DownloadMangerActiveObject(context: coreDataStack.mainContext)
    }
}