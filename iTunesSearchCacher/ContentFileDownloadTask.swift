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
    var data: NSData? { get set }
    var hasData: Bool { get set }
}

extension CollectionEntity: ContentFileDownloadTask {
    var fileID: NSManagedObjectID { return objectID }
    var fileURL: NSURL { return NSURL(string: artworkUrl)! }
    var priority: Float { return NSURLSessionTaskPriorityHigh }
    var data: NSData? {
        set { artworkData = newValue }
        get { return artworkData }
    }
    var hasData: Bool {
        set { hasArtworkData = newValue }
        get { return hasArtworkData }
    }
}

extension AudioPreviewEntity: ContentFileDownloadTask {
    var fileID: NSManagedObjectID { return objectID }
    var fileURL: NSURL { return NSURL(string: previewUrl)! }
    var priority: Float { return NSURLSessionTaskPriorityDefault }
    var data: NSData? {
        set { previewData = newValue }
        get { return previewData }
    }
    var hasData: Bool {
        set { hasPreviewData = newValue }
        get { return hasPreviewData }
    }
}
