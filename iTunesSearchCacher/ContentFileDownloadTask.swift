//
//  ContentFileDownloadTask.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 29/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

protocol ContentFileDownloadTask: class {
    var fileID: NSManagedObjectID { get }
    var fileURL: NSURL { get }
    var priority: Float { get }
}

extension CollectionEntity: ContentFileDownloadTask {
    var fileID: NSManagedObjectID { return objectID }
    var fileURL: NSURL { return NSURL(string: artworkUrl)! }
    var priority: Float { return NSURLSessionTaskPriorityHigh }
}

extension AudioPreviewEntity: ContentFileDownloadTask {
    var fileID: NSManagedObjectID { return objectID }
    var fileURL: NSURL { return NSURL(string: previewUrl)! }
    var priority: Float { return NSURLSessionTaskPriorityDefault }
}
