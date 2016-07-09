//
//  AppManager.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

class AppManager: NSObject {
    
    private let coreDataStack: CoreDataStack
    private let networking: Networking
    
    override init() {
        coreDataStack = CoreDataStack()
        networking = Networking()
        
        let rawResultsParser = RawResultsParser()
        
        super.init()
        
        networking.fetchRequestWithTerm("hello") { (rawDict: ([String : AnyObject])?) in
            if let json = rawDict {
                rawResultsParser.parseResults(json)
            }
        }
        
        
    }
}