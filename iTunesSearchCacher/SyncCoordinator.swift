//
//  SyncCoordinator.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 19/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

class SyncCoordinator {
    
    let mainManagedObjectContext: NSManagedObjectContext
    let syncManagedObjectContext: NSManagedObjectContext
    let syncGroup: dispatch_group_t = dispatch_group_create()
    var didSetup: Bool { return setupToken != 0 }
    
    private var observerTokens: [NSObjectProtocol] = [] //< The tokens registered with NSNotificationCenter
    private var setupToken = dispatch_once_t()
    
    
    init(mainManagedObjectContext mainMOC: NSManagedObjectContext) {
        assert(mainMOC.concurrencyType == .MainQueueConcurrencyType)
        mainManagedObjectContext = mainMOC
        syncManagedObjectContext = mainMOC.createBackgroundContext()
        syncManagedObjectContext.name = "SyncCoordinator"
        syncManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    private func setup() {
        dispatch_once(&setupToken) {
            self.performGroupedBlock {
                // All these need to run on the same queue, since they're modifying `observerTokens`
                self.setupContexts()
            }
        }
    }
}


protocol ChangeProcessorContextType {
    /// Wraps a block such that it is run on the right queue.
    func performGroupedBlock(block: () -> ())
    func delayedSaveOrRollback()
}

extension SyncCoordinator: ChangeProcessorContextType {
    /// This switches onto the sync context's queue. If we're already on it, it will simply run the block.
    func performGroupedBlock(block: () -> ()) {
        syncManagedObjectContext.performBlockWithGroup(syncGroup, block: block)
    }
    
    func delayedSaveOrRollback() {
        syncManagedObjectContext.delayedSaveOrRollbackWithGroup(syncGroup)
    }
}

protocol ObserverTokenStore : class {
    func addObserverToken(token: NSObjectProtocol)
}

extension SyncCoordinator: ContextOwnerType {
    func addObserverToken(token: NSObjectProtocol) {
        observerTokens.append(token)
    }
}

/// Implements the integration with Core Data change notifications.
///
/// This protocol merges changes from the main context into the sync context and vice versa.
/// It calls its `processChangedLocalObjects()` methods when objects have changed.
protocol ContextOwnerType: class, ObserverTokenStore {
    /// The UI / main thread managed object context.
    var mainManagedObjectContext: NSManagedObjectContext { get }
    /// The managed object context that is used to perform synchronization with the backend.
    var syncManagedObjectContext: NSManagedObjectContext { get }
    /// This group tracks any outstanding work.
    var syncGroup: dispatch_group_t { get }
    
    var didSetup: Bool { get }
}

extension ContextOwnerType {
    func setupContexts() {
        setupContextNotificationObserving()
    }
    
    private func setupContextNotificationObserving() {
        addObserverToken(
            mainManagedObjectContext.addContextDidSaveNotificationObserver { [weak self] notifications in
                self?.mainContextDidSave(notifications)
            }
        )
        addObserverToken(
            syncManagedObjectContext.addContextDidSaveNotificationObserver { [weak self] notifications in
                self?.syncContextDidSave(notifications)
            }
        )
    }
    
    /// Merge changes from main -> sync context.
    private func mainContextDidSave(notifications: NSNotification) {
        precondition(didSetup, "Did not call setup()")
        syncManagedObjectContext.performMergeChangesFromContextDidSaveNotification(notifications)
    }
    
    /// Merge changes from sync -> main context.
    private func syncContextDidSave(notifications: NSNotification) {
        precondition(didSetup, "Did not call setup()")
        mainManagedObjectContext.performMergeChangesFromContextDidSaveNotification(notifications)
    }
}



