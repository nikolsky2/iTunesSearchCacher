//
//  WebService.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 20/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

protocol BackgroundDownloadable: class {
    func updateProgress(taskIdentifier: Int, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    func downloadDidFinish(taskIdentifier: Int, data: NSData)
}

protocol ContentFileDownloadTaskType: class {
    var fileID: NSManagedObjectID { get }
    var fileURL: NSURL { get }
}

extension CollectionEntity: ContentFileDownloadTaskType {
    var fileID: NSManagedObjectID { return objectID }
    var fileURL: NSURL { return NSURL(string: artworkUrl)! }
}

private let maximumConnectionPerHost = 5

class WebService: NSObject {
    
    var maximumConections: Int {
        return maximumConnectionPerHost
    }
    
    weak var delegate: BackgroundDownloadable?
    
    private lazy var defaultSessionConfiguration: NSURLSessionConfiguration = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPMaximumConnectionsPerHost = maximumConnectionPerHost
        return configuration
    }()
    
    var defaultSession: NSURLSession!
    
    func startDownloadTask(request: NSURLRequest, delegate: BackgroundDownloadable) -> Int {
        let task = defaultSession.downloadTaskWithRequest(request)
        let taskIdentifier = task.taskIdentifier
        task.resume()
        return taskIdentifier
    }
    
    func start(operationQueue: NSOperationQueue) {
        defaultSession = NSURLSession(configuration: defaultSessionConfiguration, delegate: self, delegateQueue: operationQueue)
    }
    
}

// MARK: - NSURLSessionDownloadDelegate

extension WebService: NSURLSessionDownloadDelegate {
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        print("URLSession downloadTask:\(downloadTask) didFinishDownloadingToURL:\(location)")
        
        let data = NSData(contentsOfFile: location.path!)!
        delegate?.downloadDidFinish(downloadTask.taskIdentifier, data: data)
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        delegate?.updateProgress(downloadTask.taskIdentifier, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
}
