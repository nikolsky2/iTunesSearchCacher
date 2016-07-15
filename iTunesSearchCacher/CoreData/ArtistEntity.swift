//
//  ArtistEntity.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 11/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

struct RawArtistEntity {
    static let artistId         = "artistId"
    static let artistName       = "artistName"
    static let artistViewUrl    = "artistViewUrl"
}

class ArtistEntity: NSManagedObject {
    func appendCollection(collectionEntity: CollectionEntity) -> Bool {
        var collections = Array(self.collections) as! [CollectionEntity]
        let collectionIds = collections.map{ $0.collectionId } as [Int64]
        if collectionIds.contains(collectionEntity.collectionId) == false {
            collections.append(collectionEntity)
            self.collections = NSSet(array: collections)
            return true
        }
        
        return false
    }
}
