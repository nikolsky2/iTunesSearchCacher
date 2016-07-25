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
    func localFileURL(taskIdentifier: Int) -> NSURL
    func updateProgress(taskIdentifier: Int, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
    func downloadDidFinish(taskIdentifier: Int, error: NSError?)
}

protocol ContentFileDownloadTaskType: class {
    var fileID: NSManagedObjectID { get }
    var fileURL: NSURL { get }
    var localFileURL: NSURL { get }
}

extension CollectionEntity: ContentFileDownloadTaskType {
    var fileID: NSManagedObjectID { return objectID }
    var fileURL: NSURL { return NSURL(string: artworkUrl)! }
    var localFileURL: NSURL { return localArtworkUrl }
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

// MARK: - NSURLSessionTaskDelegate

extension WebService: NSURLSessionTaskDelegate {
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let theError = error where theError.domain == NSURLErrorDomain && theError.code == NSURLErrorCancelled {
            print("URLSession task:\(task) did cancel")
        } else {
            print("URLSession task:\(task) didCompleteWithError:\(error)")
            delegate?.downloadDidFinish(task.taskIdentifier, error: error)
        }
    }
}

// MARK: - NSURLSessionDownloadDelegate

extension WebService: NSURLSessionDownloadDelegate {
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        print("URLSession downloadTask:\(downloadTask) didFinishDownloadingToURL:\(location)")
        
        if let downloadDelegate = delegate {
            //print("BackgroundDownloadManager finished download with id: \(downloadTask.taskIdentifier)")
            
            let localFileURL = downloadDelegate.localFileURL(downloadTask.taskIdentifier)
            
            do {
                if NSFileManager.defaultManager().fileExistsAtPath(localFileURL.path!) {
                    try NSFileManager.defaultManager().removeItemAtURL(localFileURL)
                }
                print("Saving file: \(localFileURL.lastPathComponent!)")
                try NSFileManager.defaultManager().moveItemAtURL(location, toURL: localFileURL)
            }
            catch let error as NSError {
                delegate?.downloadDidFinish(downloadTask.taskIdentifier, error: error)
            }
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        delegate?.updateProgress(downloadTask.taskIdentifier, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
}
