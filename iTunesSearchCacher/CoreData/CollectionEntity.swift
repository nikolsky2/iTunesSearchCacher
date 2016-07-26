//
//  CollectionEntity.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 11/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

struct RawCollectionEntity {
    static let artworkUrl           = "artworkUrl100"
    static let collectionId         = "collectionId"
    static let collectionName       = "collectionName"
    static let collectionViewUrl    = "collectionViewUrl"
    static let primaryGenreName     = "primaryGenreName"
}

class CollectionEntity: NSManagedObject {
    func appendTrack(trackEntity: TrackEntity) -> Bool {
        var tracks = Array(self.tracks) as! [TrackEntity]
        let tracksIds = tracks.map{ $0.trackId } as [Int64]
        if tracksIds.contains(trackEntity.trackId) == false {
            tracks.append(trackEntity)
            self.tracks = NSSet(array: tracks)
            return true
        }
        
        return false
    }
}

extension CollectionEntity {
    static var defaultSortDescriptor: NSSortDescriptor {
        return NSSortDescriptor(key: "collectionName", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
    }
}
