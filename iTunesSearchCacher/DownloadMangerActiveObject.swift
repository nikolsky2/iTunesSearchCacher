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
                self.privateContext.performBlockAndWait({ () -> Void in
                    guard let userInfo = notification.userInfo as? [String: NSObject] else { return }
                    
                    func objectsWithChangeType(changeType: String) -> Set<NSManagedObject>? {
                        return (userInfo[changeType] as? Set<NSManagedObject>) ?? nil
                    }
                    
                    if let updated = objectsWithChangeType(NSUpdatedObjectsKey) {
                        updated.forEach {
                            if let preview = $0 as? AudioPreviewEntity where self.previewNeedsDownloadPredicate.evaluateWithObject(preview) {
                                self.dispatchNewDownload($0 as! ContentFileDownloadTask)
                            }
                        }
                    }
                    self.privateContext.mergeChangesFromContextDidSaveNotification(notification)
                })
            }
        }
        
        webService.delegate = self
        webService.start(operationQueue)
        
        performFetchAndSheduleDownloads()
    }
    
    private func performFetchAndSheduleDownloads() {
        performCollectionsFetch()
        performAudioFetch()
        produceNewDownloads()
    }
    
    private func performCollectionsFetch() {
        privateContext.performBlockAndWait {
            let fetchRequest = NSFetchRequest(entityName: CollectionEntity.className)
            let collectionFetchPredicate = NSPredicate(format: "hasArtworkData == NO")
            fetchRequest.predicate = collectionFetchPredicate
            fetchRequest.sortDescriptors = [CollectionEntity.defaultSortDescriptor]
            self.collectionsFetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.privateContext, sectionNameKeyPath: nil, cacheName: nil)
            self.collectionsFetchResultsController.delegate = self
            try! self.collectionsFetchResultsController.performFetch()
            
            let collections = self.collectionsFetchResultsController.fetchedObjects as! [CollectionEntity]
            collections.forEach { self.pendingQueue.push($0) }
        }
    }
    
    private func performAudioFetch() {
        privateContext.performBlockAndWait {
            let fetchRequest = NSFetchRequest(entityName: AudioPreviewEntity.className)
            let collectionFetchPredicate = self.previewNeedsDownloadPredicate
            fetchRequest.predicate = collectionFetchPredicate
            fetchRequest.sortDescriptors = [AudioPreviewEntity.defaultSortDescriptor]
            self.audioFetchResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.privateContext, sectionNameKeyPath: nil, cacheName: nil)
            self.audioFetchResultsController.delegate = self
            try! self.audioFetchResultsController.performFetch()
            
            let previews = self.audioFetchResultsController.fetchedObjects as! [AudioPreviewEntity]
            previews.forEach { self.pendingQueue.push($0) }
        }
    }
    
    private var previewNeedsDownloadPredicate: NSPredicate {
        return NSPredicate(format: "hasPreviewData == NO AND needsDownload == YES")
    }
    
    private var isProducingNewDownloads: Bool {
        return activeTasks.count < webService.maximumConections && !pendingQueue.isEmpty
    }

    private func produceNewDownloads() {
        guard isProducingNewDownloads else { return }
        while isProducingNewDownloads {
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
    
    private func saveChangesWithAction(action: () -> (), completion: () -> ()) throws {
        privateContext.performBlockAndWait {
            action()
            do {
                try self.privateContext.save()
                completion()
            }
            catch {
                fatalError("failure to save context: \(error)")
            }
        }
    }
    
    private func dispatchNewDownload(task: ContentFileDownloadTask) {
        dispatch_sync(operationQueue.underlyingQueue!) {
            self.pendingQueue.push(task)
            self.produceNewDownloads()
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
        try! saveChangesWithAction({
            let collection = self.privateContext.objectWithID(self.activeTasks[taskIdentifier]!.fileID) as! ContentFileDownloadTask
            collection.data = data
            collection.hasData = true
            }, completion: { [weak self] in
                if let strongSelf = self {
                    dispatch_async(strongSelf.operationQueue.underlyingQueue!) {
                        strongSelf.activeTasks.removeValueForKey(taskIdentifier)
                        strongSelf.activeProgress.removeValueForKey(taskIdentifier)
                        strongSelf.produceNewDownloads()
                        
                        print("Finished task. Active: \(strongSelf.activeTasks.count), pending: \(strongSelf.pendingQueue.count)")
                    }
                }
            })
    }
}

extension ContentDownloadManager: NSFetchedResultsControllerDelegate {
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        guard type == .Insert else { return }
        
        let task = anObject as! ContentFileDownloadTask
        dispatchNewDownload(task)
    }
}

//MARK: -


