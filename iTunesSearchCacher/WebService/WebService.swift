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
    
    func startDownloadTask(request: NSURLRequest, priority: Float) -> Int {
        let task = defaultSession.downloadTaskWithRequest(request)
        task.priority = priority
        task.resume()
        return task.taskIdentifier
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
        } else if error != nil {
            print("URLSession task:\(task) didCompleteWithError:\(error)")
        }
    }
}

// MARK: - NSURLSessionDownloadDelegate

extension WebService: NSURLSessionDownloadDelegate {
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        //print("URLSession downloadTask:\(downloadTask) didFinishDownloadingToURL:\(location)")
        
        let data = NSData(contentsOfFile: location.path!)!
        delegate?.downloadDidFinish(downloadTask.taskIdentifier, data: data)
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        delegate?.updateProgress(downloadTask.taskIdentifier, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }
    
}
