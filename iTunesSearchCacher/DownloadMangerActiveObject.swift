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
    func downloadFiles(fileIDs: [NSManagedObjectID])
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
    
    func downloadFiles(fileIDs: [NSManagedObjectID]) {
        performSyncOnActiveObject({ contentDownloadManager in
            contentDownloadManager.downloadFiles(fileIDs)
        })
    }
}

//MARK: -
//MARK: ContentDownloadManager

class ContentDownloadManager: NSObject {
    
    let privateContext: NSManagedObjectContext
    let operationQueue: NSOperationQueue
    let webService: WebService
    
    private let downloadsLimit = 20
    private var allTasks = [NSManagedObjectID: ContentFileDownloadTaskType]()
    private var activeTasks = Set<NSManagedObjectID>()
    private var allTaskByIDs = [Int: ContentFileDownloadTaskType]()
    
    deinit {
        print("ContentDownloadServiceContext deinit")
    }
    
    private init(operationQueue: NSOperationQueue, privateContext: NSManagedObjectContext) {
        self.operationQueue = operationQueue
        self.privateContext = privateContext
        self.webService = WebService()
        
        super.init()
    }
    
    private func scheduleFileWithID(fileID: NSManagedObjectID) {
        let entityTask = privateContext.objectWithID(fileID) as! ContentFileDownloadTaskType
        allTasks[entityTask.fileID] = entityTask
    }
    
    private var hasAvailableDownloadSlot: Bool {
        return downloadsLimit > activeTasks.count
    }
    
    private func produceNewDownloads() {
        let oldCount = activeTasks.count
        
        try! performBulkyManagedObjectContextAction {
            while hasAvailableDownloadSlot && !allTasks.isEmpty {
                if let fileID = allTasks.first?.0, task = allTasks[fileID] {
                    startDownloadTask(task)
                }
            }
        }
        
        print("produceNewDownloads \(activeTasks.count - oldCount)")
    }
    
    private func startDownloadTask(task: ContentFileDownloadTaskType) {
        self.activeTasks.insert(task.fileID)
        startDownloadTask(task)
    }
    
    private func startDownload(task: ContentFileDownloadTaskType) {
        let url = NSURL(string: task.fileURL)!
        let request = NSURLRequest(URL: url)
        
        let taskIdentifier = webService.startDownloadTask(request, delegate: self)
        print("taskIdentifier = \(taskIdentifier)")
        allTaskByIDs[taskIdentifier] = task
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
    var downloadProgress: NSProgress? {
        return nil
    }
    
    var downloadDestination: NSURL {
        return NSFileManager.downloadDirectory()
    }
    
    func downloadDidFinish(taskIdentifier: Int, error: NSError?) {
        if let task = allTaskByIDs[taskIdentifier] {
            allTasks.removeValueForKey(task.fileID)
            activeTasks.remove(task.fileID)
            allTaskByIDs.removeValueForKey(taskIdentifier)
        }
        
        produceNewDownloads()
    }
}

//MARK: - ContentDownloadManaging

extension ContentDownloadManager: ContentDownloadManaging {
    func start() {
        webService.start(operationQueue)
    }

    func downloadFiles(fileIDs: [NSManagedObjectID]) {
        privateContext.refreshAllObjects()
        fileIDs.forEach({ fileID in scheduleFileWithID(fileID) })
        produceNewDownloads()
    }
}

//MARK: -








