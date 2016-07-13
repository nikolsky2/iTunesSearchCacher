//
//  TrackEntity.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 11/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

struct RawTrackEntity {
    static let previewUrl   = "previewUrl"
    static let trackId      = "trackId"
    static let trackName    = "trackName"
    static let trackNumber  = "trackNumber"
}

class TrackEntity: NSManagedObject {
    class func create(rawValue: [String : AnyObject], context: NSManagedObjectContext) -> TrackEntity? {
        
        if let previewUrl = rawValue[RawTrackEntity.previewUrl] as? String,
            let trackId = rawValue[RawTrackEntity.trackId] as? NSNumber,
            let trackName = rawValue[RawTrackEntity.trackName] as? String,
            let trackNumber = rawValue[RawTrackEntity.trackNumber] as? NSNumber {
            
            let entity: TrackEntity = context.createEntity()
            
            entity.previewUrl = previewUrl
            entity.trackId = trackId.longLongValue
            entity.trackName = trackName
            entity.trackNumber = trackNumber.longLongValue
            
            return entity
        }
        
        return nil
    }
}
