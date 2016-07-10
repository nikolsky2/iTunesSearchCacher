//
//  AppManager.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import UIKit

class AppManager: NSObject {
    
    private var coreDataStack: CoreDataStack!
    
    class func shared() -> AppManager {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        return appDelegate.appManager
    }
    
    lazy var window: UIWindow = {
        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        return window
    }()
    
    func didFinishLaunching() {
        coreDataStack = CoreDataStack()
        
        let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil)
        let navViewController = mainStoryBoard.instantiateInitialViewController()
        window.rootViewController = navViewController
        window.makeKeyAndVisible()
    }
}