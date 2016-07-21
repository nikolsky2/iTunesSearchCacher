//
//  NSManagedObjectContext+Extensions.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 20/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
    func createBackgroundContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        return context
    }
    
    func performBlockWithGroup(group: dispatch_group_t, block: () -> ()) {
        dispatch_group_enter(group)
        performBlock {
            block()
            dispatch_group_leave(group)
        }
    }
    
    /// Adds the given block to the default `NSNotificationCenter`'s dispatch table for the given context's did-save notifications.
    /// - returns: An opaque object to act as the observer. This must be sent to the default `NSNotificationCenter`'s `removeObserver()`.
    func addContextDidSaveNotificationObserver(handler: NSNotification -> ()) -> NSObjectProtocol {
        let nc = NSNotificationCenter.defaultCenter()
        return nc.addObserverForName(NSManagedObjectContextDidSaveNotification, object: self, queue: nil) { notification in
            handler(notification)
        }
    }
    
    func performMergeChangesFromContextDidSaveNotification(notification: NSNotification) {
        performBlock {
            self.mergeChangesFromContextDidSaveNotification(notification)
        }
    }
    
    func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        } catch {
            rollback()
            return false
        }
    }
    
    func performSaveOrRollback() {
        performBlock {
            self.saveOrRollback()
        }
    }
    
    private var changedObjectsCount: Int {
        return insertedObjects.count + updatedObjects.count + deletedObjects.count
    }
    
    func delayedSaveOrRollbackWithGroup(group: dispatch_group_t, completion: (Bool) -> () = { _ in }) {
        let changeCountLimit = 100
        guard changeCountLimit >= changedObjectsCount else { return completion(saveOrRollback()) }
        let queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
        dispatch_group_notify(group, queue) {
            self.performBlockWithGroup(group) {
                guard self.hasChanges else { return completion(true) }
                completion(self.saveOrRollback())
            }
        }
    }
    
}