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
    class func create(rawValue: [String : AnyObject], context: NSManagedObjectContext) -> ArtistEntity? {
        if let artistId = rawValue[RawArtistEntity.artistId] as? NSNumber,
            let artistName = rawValue[RawArtistEntity.artistName] as? String,
            let artistViewUrl = rawValue[RawArtistEntity.artistViewUrl] as? String {
            
            let entity: ArtistEntity = context.createEntity()
            entity.artistId = artistId.longLongValue
            entity.artistName = artistName
            entity.artistViewUrl = artistViewUrl
            
            return entity
        }
        
        return nil
    }
}
