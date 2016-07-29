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

    private var pendingQueue = PriorityQueue<ContentFileDownloadTask>({ $0.priority > $1.priority })
    private var activeTasks = [Int: ContentFileDownloadTask]()
    private var activeProgress = [Int: NSProgress]()
    
    private var collectionsFetchResultsController: NSFetchedResultsController!
    private var audioFetchResultsController: NSFetchedResultsController!
    
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
                })
            }
        }
        
        webService.delegate = self
        webService.start(operationQueue)
        
        performCollectionsFetch()
        performAudioFetch()
        
        produceNewDownloads()
    }
    
    private func performCollectionsFetch() {
        let fetchRequest = NSFetchRequest(entityName: CollectionEntity.className)
        let collectionFetchPredicate = NSPredicate(format: "hasArtworkData == NO")
        fetchRequest.predicate = collectionFetchPredicate
        fetchRequest.sortDescriptors = [CollectionEntity.defaultSortDescriptor]
        collectionsFetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: privateContext, sectionNameKeyPath: nil, cacheName: nil)
        collectionsFetchResultsController.delegate = self
        try! collectionsFetchResultsController.performFetch()
        
        let collections = collectionsFetchResultsController.fetchedObjects as! [CollectionEntity]
        collections.forEach { pendingQueue.push($0) }
    }
    
    func performAudioFetch() {
        let fetchRequest = NSFetchRequest(entityName: AudioPreviewEntity.className)
        let collectionFetchPredicate = NSPredicate(format: "hasPreviewData == NO")
        fetchRequest.predicate = collectionFetchPredicate
        fetchRequest.sortDescriptors = [AudioPreviewEntity.defaultSortDescriptor]
        audioFetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: privateContext, sectionNameKeyPath: nil, cacheName: nil)
        audioFetchResultsController.delegate = self
        try! audioFetchResultsController.performFetch()
        
        let previews = audioFetchResultsController.fetchedObjects as! [AudioPreviewEntity]
        previews.forEach { pendingQueue.push($0) }
    }
    
    private var hasAvailableDownloadSlot: Bool {
        return activeTasks.count < webService.maximumConections
    }
    
    private func produceNewDownloads() {
        guard hasAvailableDownloadSlot && !pendingQueue.isEmpty else { return }
        
        while hasAvailableDownloadSlot && !pendingQueue.isEmpty {
            let task = pendingQueue.pop()!
            startDownloadTask(task)
        }
        
        print("Produced new tasks. Active: \(activeTasks.count), pending: \(pendingQueue.count)")
    }
        
    private func startDownloadTask(task: ContentFileDownloadTask) {
        let request = NSURLRequest(URL: task.fileURL)
        let taskIdentifier = webService.startDownloadTask(request, priority: task.priority)
        activeTasks[taskIdentifier] = task
        print("startDownloadTask taskIdentifier = \(taskIdentifier)")
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
            let collection = privateContext.objectWithID(activeTasks[taskIdentifier]!.fileID) as! ContentFileDownloadTask
            collection.data = data
            collection.hasData = true
        }
        
        activeTasks.removeValueForKey(taskIdentifier)
        activeProgress.removeValueForKey(taskIdentifier)
        
        produceNewDownloads()
        
        print("Finished task. Active: \(activeTasks.count), pending: \(pendingQueue.count)")
    }
}

extension ContentDownloadManager: NSFetchedResultsControllerDelegate {
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type {
        case .Insert:
            dispatch_sync(operationQueue.underlyingQueue!) {
                let collection = anObject as! ContentFileDownloadTask
                self.pendingQueue.push(collection)
                self.produceNewDownloads()
            }
        default:
            break
        }
    }
}

//MARK: -


