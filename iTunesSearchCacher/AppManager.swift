//
//  AppManager.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

class AppManager: NSObject {
    
    private var coreDataStack: CoreDataStack
    private var networking: Networking
    
    override init() {
        coreDataStack = CoreDataStack()
        networking = Networking()
        
        super.init()
        
        
        
        
    }
}