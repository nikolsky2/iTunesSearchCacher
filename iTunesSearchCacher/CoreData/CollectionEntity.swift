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
    class func create(rawValue: [String : AnyObject], context: NSManagedObjectContext) -> CollectionEntity? {
        if let artworkUrl = rawValue[RawCollectionEntity.artworkUrl] as? String,
            let collectionId = rawValue[RawCollectionEntity.collectionId] as? NSNumber,
            let collectionName = rawValue[RawCollectionEntity.collectionName] as? String,
            let collectionViewUrl = rawValue[RawCollectionEntity.collectionViewUrl] as? String,
            let primaryGenreName = rawValue[RawCollectionEntity.primaryGenreName] as? String {
            
            let entity: CollectionEntity = context.createEntity()
            
            entity.artworkUrl = artworkUrl
            entity.collectionId = collectionId.longLongValue
            entity.collectionName = collectionName
            entity.collectionViewUrl = collectionViewUrl
            entity.primaryGenreName = primaryGenreName
            
            return entity
        }
        
        return nil
    }
}
