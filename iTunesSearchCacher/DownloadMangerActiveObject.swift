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
    private var context: NSManagedObjectContext!
    private let operationQueue: NSOperationQueue
    private var contentDownloadManager: ContentDownloadManager!
    
    deinit {
        print("ContentDownloadMangerActiveObject deinit")
    }
    
    init(context: NSManagedObjectContext) {
        operationQueue = NSOperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.underlyingQueue = dispatch_queue_create("com.happyTuna.iTunesSearchCacher.DownloadMangerActiveObject", nil)
        
        self.context = context
        
        super.init()
        
        contentDownloadManager = self.performSyncOnPrivateQueue {
            ContentDownloadManager(operationQueue: self.operationQueue, privateContext: context.createBackgroundContext())
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

    private var pendingQueue = [ContentFileDownloadTaskType]()
    private var activeTasks = [Int: ContentFileDownloadTaskType]()
    private var activeProgress = [Int: NSProgress]()
    
    deinit {
        print("ContentDownloadServiceContext deinit")
    }
    
    private init(operationQueue: NSOperationQueue, privateContext: NSManagedObjectContext) {
        self.operationQueue = operationQueue
        self.privateContext = privateContext
        self.webService = WebService()
        
        super.init()
        
        webService.delegate = self
    }
    
    private var hasAvailableDownloadSlot: Bool {
        return activeTasks.count < webService.maximumConections
    }
    
    private func produceNewDownloads() {
        let oldCount = activeTasks.count
        
        try! performBulkyManagedObjectContextAction {
            while hasAvailableDownloadSlot && !pendingQueue.isEmpty {
                
                let task = pendingQueue.first!
                startDownloadTask(task)
                pendingQueue.removeFirst()
            }
        }
        
        print("produceNewDownloads \(activeTasks.count - oldCount)")
    }
        
    private func startDownloadTask(task: ContentFileDownloadTaskType) {
        let request = NSURLRequest(URL: task.fileURL)
        let taskIdentifier = webService.startDownloadTask(request, delegate: self)
        print("taskIdentifier = \(taskIdentifier)")
        activeTasks[taskIdentifier] = task
    }
    
//MARK: - Context managment
    
    private var bulkyManagedObjectContextActionCounter = 0
    func beginBulkyManagedObjectContextAction() {
        bulkyManagedObjectContextActionCounter += 1
    }
    
    func endBulkyManagedObjectContextAction() {
        assert(bulkyManagedObjectContextActionCounter > 0)
        bulkyManagedObjectContextActionCounter -= 1
        if bulkyManagedObjectContextActionCounter == 0 && privateContext.hasChanges {
            
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
    
    func performBulkyManagedObjectContextAction(@noescape action: () throws -> Void ) throws {
        beginBulkyManagedObjectContextAction()
        try action()
        endBulkyManagedObjectContextAction()
    }
}

extension ContentDownloadManager: BackgroundDownloadable {
    
    func localFileURL(taskIdentifier: Int) -> NSURL {
        if let task = activeTasks[taskIdentifier] {
            return task.localFileURL
        } else {
            fatalError("task is not found for taskIdentifier")
        }
    }
    
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
    
    func downloadDidFinish(taskIdentifier: Int, error: NSError?) {
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
        pendingQueue = allCollections.filter{ !$0.isArtworkDownloaded }.map {$0 as ContentFileDownloadTaskType}
        produceNewDownloads()
    }
}

//MARK: -








