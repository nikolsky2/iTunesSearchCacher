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
    var localArtworkUrl: NSURL {
        let documentsURL = NSFileManager.downloadDirectory()
        let artwokrUrl = NSURL(string: artworkUrl)!
        let artworkFileName = artwokrUrl.lastPathComponent!
        
        //collectionId + 100x100bb.jpg
        //580708520.artwork.100x100bb.jpg
        
        let url = documentsURL.URLByAppendingPathComponent(String(collectionId) + ".artwork." + artworkFileName)
        return url
    }
    
    var isArtworkDownloaded: Bool {
        var isDirectory: ObjCBool = false
        return NSFileManager.defaultManager().fileExistsAtPath(localArtworkUrl.path!, isDirectory: &isDirectory)
    }
}
