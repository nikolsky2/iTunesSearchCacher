//
//  Operations.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 22/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

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

//MARK: -
//MARK: ContentDownloadManager

class ContentDownloadManager: NSObject {
    
    let privateContext: NSManagedObjectContext
    let operationQueue: NSOperationQueue
    let webService: WebService
    private var contextObserver: AnyObject!

    private var pendingQueue = [ContentFileDownloadTaskType]()
    private var activeTasks = [Int: ContentFileDownloadTaskType]()
    private var activeProgress = [Int: NSProgress]()
    private var collectionsFetchResultsController: NSFetchedResultsController!
    
    deinit {
        print("ContentDownloadServiceContext deinit")
    }
    
    private init(operationQueue: NSOperationQueue, context: NSManagedObjectContext) {
        self.operationQueue = operationQueue
        self.privateContext = context.createBackgroundContext()
        self.webService = WebService()
        
        let collectionFetchRequest = NSFetchRequest(entityName: CollectionEntity.className)
        let collectionFetchPredicate = NSPredicate(format: "artworkData = nil")
        collectionFetchRequest.predicate = collectionFetchPredicate
        collectionFetchRequest.sortDescriptors = [CollectionEntity.defaultSortDescriptor]
        
        super.init()
        
        contextObserver = NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil) {
            notification in
            
            if let context = notification.object as? NSManagedObjectContext where context !== self.privateContext {
                self.privateContext.performBlock({ () -> Void in
                    self.privateContext.mergeChangesFromContextDidSaveNotification(notification)
                })
            }
        }
        
        webService.delegate = self
        webService.start(operationQueue)
        
        collectionsFetchResultsController = NSFetchedResultsController(fetchRequest: collectionFetchRequest, managedObjectContext: privateContext, sectionNameKeyPath: nil, cacheName: nil)
        collectionsFetchResultsController.delegate = self
        try! collectionsFetchResultsController.performFetch()
        
        let collections = collectionsFetchResultsController.fetchedObjects as! [CollectionEntity]
        pendingQueue.appendContentsOf(collections.map{ $0 as ContentFileDownloadTaskType})
        
        produceNewDownloads()
    }
    
    private var hasAvailableDownloadSlot: Bool {
        return activeTasks.count < webService.maximumConections
    }
    
    private func produceNewDownloads() {
        guard hasAvailableDownloadSlot && !pendingQueue.isEmpty else { return }
        
        while hasAvailableDownloadSlot && !pendingQueue.isEmpty {
            let task = pendingQueue.first!
            startDownloadTask(task)
            pendingQueue.removeFirst()
        }
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
            privateContext.performBlock {
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

extension ContentDownloadManager: NSFetchedResultsControllerDelegate {
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type {
        case .Insert:
            dispatch_sync(operationQueue.underlyingQueue!) {
                let collection = anObject as! ContentFileDownloadTaskType
                self.pendingQueue.append(collection)
                self.produceNewDownloads()
            }
        default:
            break
        }
    }
}

//MARK: -


