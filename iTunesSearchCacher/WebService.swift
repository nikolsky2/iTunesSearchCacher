//
//  WebService.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 20/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

protocol BackgroundDownloadable {
    var downloadProgress: NSProgress? { get }
    var downloadDestination: NSURL { get }
    func downloadDidFinish(taskIdentifier: Int, error: NSError?)
}

protocol ContentFileDownloadTaskType: class {
    var fileID: NSManagedObjectID { get }
    var fileURL: NSURL { get }
}

extension CollectionEntity: ContentFileDownloadTaskType {
    var fileID: NSManagedObjectID { return objectID }
    var fileURL: NSURL { return localArtworkUrl }
}

private let maximumConnectionPerHost = 5

private struct Download {
    init(downloadDelegate: BackgroundDownloadable, downloadTask: NSURLSessionDownloadTask? = nil) {
        self.downloadDelegate = downloadDelegate
        self.downloadTask = downloadTask
    }
    
    let downloadDelegate: BackgroundDownloadable
    var downloadTask: NSURLSessionDownloadTask?
}

class WebService: NSObject {
    
    var maximumConections: Int {
        return maximumConnectionPerHost
    }

    private var downloads = [Int: Download]()
    
    private lazy var defaultSessionConfiguration: NSURLSessionConfiguration = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPMaximumConnectionsPerHost = maximumConnectionPerHost
        return configuration
    }()
    
    var defaultSession: NSURLSession!
    
    private func delegateForTask(downloadTask: NSURLSessionDownloadTask) -> BackgroundDownloadable? {
        if var download = downloads[downloadTask.taskIdentifier] {
            if download.downloadTask == nil {
                download.downloadTask = downloadTask
            }
            
            return download.downloadDelegate
        }
        
        return nil
    }
    
    func startDownloadTask(request: NSURLRequest, delegate: BackgroundDownloadable) -> Int {
        let task = defaultSession.downloadTaskWithRequest(request)
        
        let download = Download(downloadDelegate: delegate, downloadTask: task)
        let taskIdentifier = task.taskIdentifier
        
        downloads[taskIdentifier] = download
        
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
        }
        else if let downloadTask = task as? NSURLSessionDownloadTask, delegate = delegateForTask(downloadTask) {
            print("URLSession task:\(task) didCompleteWithError:\(error)")
            
            delegate.downloadDidFinish(task.taskIdentifier, error: error)
            downloads.removeValueForKey(task.taskIdentifier)
        }
    }
}

// MARK: - NSURLSessionDownloadDelegate

extension WebService: NSURLSessionDownloadDelegate {
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        print("URLSession downloadTask:\(downloadTask) didFinishDownloadingToURL:\(location)")
        
        if let delegate = delegateForTask(downloadTask) {
            print("BackgroundDownloadManager finished download with id: \(downloadTask.taskIdentifier)")
            
            var correctedLocation = location
            
            if let cachePath = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true).first {
                
                func applicationUIDComponentIndex(components: [String]) -> Int? {
                    if let index = components.indexOf("Application")?.successor() where index < components.endIndex {
                        return index
                    }
                    
                    return nil
                }
                
                let cacheURL = NSURL(fileURLWithPath: cachePath, isDirectory: true)
                if  let locationComponents = location.pathComponents,
                    locationApplicationUIDComponentIndex = applicationUIDComponentIndex(locationComponents),
                    cachePathComponents = cacheURL.pathComponents,
                    cacheApplicationUIDComponentIndex = applicationUIDComponentIndex(cachePathComponents)
                {
                    var correctedPathComponents = locationComponents
                    correctedPathComponents[locationApplicationUIDComponentIndex] = cachePathComponents[cacheApplicationUIDComponentIndex]
                    
                    if let url = NSURL.fileURLWithPathComponents(correctedPathComponents) {
                        correctedLocation = url
                    }
                }
            }
            
            do {
                if NSFileManager.defaultManager().fileExistsAtPath(delegate.downloadDestination.path!) {
                    try NSFileManager.defaultManager().removeItemAtURL(delegate.downloadDestination)
                }
                try NSFileManager.defaultManager().moveItemAtURL(correctedLocation, toURL: delegate.downloadDestination)
            }
            catch let error as NSError {
                delegate.downloadDidFinish(downloadTask.taskIdentifier, error: error)
                downloads.removeValueForKey(downloadTask.taskIdentifier)
            }
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let progress = delegateForTask(downloadTask)?.downloadProgress {
            progress.totalUnitCount = totalBytesExpectedToWrite
            progress.completedUnitCount = totalBytesWritten
        }
    }
    
}
