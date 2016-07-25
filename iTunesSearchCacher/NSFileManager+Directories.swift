//
//  NSFileManager+Directories.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 23/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

extension NSFileManager {
    static func downloadDirectory() -> NSURL {
        if let downloadDirectory = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).first {
            let url = NSURL(fileURLWithPath: downloadDirectory).URLByAppendingPathComponent("Downloads")
            
            var isDirectory: ObjCBool = true
            if NSFileManager.defaultManager().fileExistsAtPath(url.path!, isDirectory: &isDirectory) {
                return url
            } else {
                do {
                    try NSFileManager.defaultManager().createDirectoryAtPath(url.path!, withIntermediateDirectories: true, attributes: nil)
                }
                catch {
                    assert(false, "error with creating a folder")
                }
                
                return url
            }
        }
        
        assert(false, "error with creating a folder")
    }
}