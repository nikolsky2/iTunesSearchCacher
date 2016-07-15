//
//  Trackable.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 15/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

protocol TrackViewModel: class {
    var topString: String { get }
    var bottomString: String { get }
}

extension TrackEntity: TrackViewModel {
    var topString: String {
        return trackName + " (" + collection.collectionName + ")"
    }
    var bottomString: String {
        return "Song by " + collection.artist.artistName
    }
}

protocol Trackable: class {
    static func trackableId() -> String
}

extension TrackEntity: Trackable {
    static func trackableId() -> String {
        return "trackId"
    }
}

extension NSManagedObjectContext {
    func fetchWithIds<T: NSManagedObject where T: Trackable>(ids: [NSNumber]) -> [T] {
        
        let fetchRequest = NSFetchRequest(entityName: T.className)
        fetchRequest.predicate = NSPredicate(format: T.trackableId() + " IN %@", ids)
        let objects = try! self.executeFetchRequest(fetchRequest) as! [T]
        
        return objects
    }
}

