//
//  Operations.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 22/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

protocol ContentDownloadManaging {
    func start()
    func downloadFiles()
}

//MARK: -
//MARK: DownloadMangerActiveObject

class DownloadMangerActiveObject: NSObject {
    private let operationQueue: NSOperationQueue
    private var contentDownloadManager: ContentDownloadManager!
    
    deinit {
        print("ContentDownloadMangerActiveObject deinit")
    }
    
    init(context: NSManagedObjectContext) {
        operationQueue = NSOperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.underlyingQueue = dispatch_queue_create("com.happyTuna.iTunesSearchCacher.DownloadMangerActiveObject", nil)
        
        super.init()
        
        contentDownloadManager = self.performSyncOnPrivateQueue {
            ContentDownloadManager(operationQueue: self.operationQueue, context: context)
        }
    }
    
    private func performSyncOnActiveObject<T>(action:(contentDownloadManager: ContentDownloadManager) -> T) -> T {
        return performSyncOnPrivateQueue { action(contentDownloadManager: self.contentDownloadManager) }
    }
    
    private func performSyncOnPrivateQueue<T>(action:() -> T) -> T {
        var result: T!
        
        dispatch_sync(operationQueue.underlyingQueue!) {
            result = action()
        }
        
        if result == nil {
            fatalError("should not be nil")
        }
        
        return result
    }
    
    private func performAsyncOnActiveObject(action:(contentDownloadManager: ContentDownloadManager) -> Void) {
        performAsyncOnPrivateQueue { [weak self] in
            if let strongSelf = self {
                action(contentDownloadManager: strongSelf.contentDownloadManager)
            }
        }
    }
    
    private func performAsyncOnPrivateQueue(action:() -> Void) {
        operationQueue.addOperation(NSBlockOperation(block:action))
    }
}

extension DownloadMangerActiveObject: ContentDownloadManaging {
    
    func start() {
        performAsyncOnPrivateQueue(contentDownloadManager.start)
    }
    
    func downloadFiles() {
        performSyncOnActiveObject({ contentDownloadManager in
            contentDownloadManager.downloadFiles()
        })
    }
}

//MARK: -
//MARK: ContentDownloadManager

private class ContentDownloadManager: NSObject {
    
    let privateContext: NSManagedObjectContext
    let operationQueue: NSOperationQueue
    let webService: WebService
    private var contextObserver: AnyObject!

    private var pendingQueue = [ContentFileDownloadTaskType]()
    private var activeTasks = [Int: ContentFileDownloadTaskType]()
    private var activeProgress = [Int: NSProgress]()
    
    deinit {
        print("ContentDownloadServiceContext deinit")
    }
    
    private init(operationQueue: NSOperationQueue, context: NSManagedObjectContext) {
        self.operationQueue = operationQueue
        self.privateContext = context.createBackgroundContext()
        self.webService = WebService()
        
        super.init()
        
        contextObserver = NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil) {
            notification in
            
            if let context = notification.object as? NSManagedObjectContext where context !== self.privateContext {
                self.privateContext.performBlock({ () -> Void in
                    self.privateContext.mergeChangesFromContextDidSaveNotification(notification)
                    
                    //Append or start new donwloads
                    dispatch_sync(operationQueue.underlyingQueue!) {
                        self.downloadFiles()
                    }
                })
            }
        }
        
        webService.delegate = self
    }
    
    private var hasAvailableDownloadSlot: Bool {
        return activeTasks.count < webService.maximumConections
    }
    
    private func produceNewDownloads() {
        guard pendingQueue.count != 0 else { return }
        
        let oldCount = activeTasks.count
        
        while hasAvailableDownloadSlot && !pendingQueue.isEmpty {
            let task = pendingQueue.first!
            startDownloadTask(task)
            pendingQueue.removeFirst()
        }
        
        print("produceNewDownloads \(activeTasks.count - oldCount)")
    }
        
    private func startDownloadTask(task: ContentFileDownloadTaskType) {
        let request = NSURLRequest(URL: task.fileURL)
        let taskIdentifier = webService.startDownloadTask(request, delegate: self)
        print("taskIdentifier = \(taskIdentifier)")
        activeTasks[taskIdentifier] = task
    }
    
    private func saveChangesWithAction(@noescape action: () -> Void ) throws {
        action()
        if privateContext.hasChanges {
            privateContext.performBlockAndWait {
                do {
                    try self.privateContext.save()
                }
                catch {
                    fatalError("failure to save context: \(error)")
                }
            }
        }
    }
}

extension ContentDownloadManager: BackgroundDownloadable {
    
    func updateProgress(taskIdentifier: Int, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        var taskProgress: NSProgress!
        if let progress = activeProgress[taskIdentifier] {
            taskProgress = progress
        } else {
            taskProgress = NSProgress()
            activeProgress[taskIdentifier] = taskProgress
        }
        
        taskProgress.totalUnitCount = totalBytesExpectedToWrite
        taskProgress.completedUnitCount = totalBytesWritten
    }
    
    func downloadDidFinish(taskIdentifier: Int, data: NSData) {
        
        try! saveChangesWithAction {
            let collection = privateContext.objectWithID(activeTasks[taskIdentifier]!.fileID) as! CollectionEntity
            collection.artworkData = data
        }
        
        activeTasks.removeValueForKey(taskIdentifier)
        activeProgress.removeValueForKey(taskIdentifier)
        
        produceNewDownloads()
    }
}

//MARK: - ContentDownloadManaging

extension ContentDownloadManager: ContentDownloadManaging {
    func start() {
        webService.start(operationQueue)
    }

    func downloadFiles() {
        let fetchRequest = NSFetchRequest(entityName: CollectionEntity.className)
        let allCollections = try! privateContext.executeFetchRequest(fetchRequest) as! [CollectionEntity]
        pendingQueue = allCollections.filter{ $0.artworkData == nil }.map {$0 as ContentFileDownloadTaskType}
        produceNewDownloads()
    }
}

//MARK: -








