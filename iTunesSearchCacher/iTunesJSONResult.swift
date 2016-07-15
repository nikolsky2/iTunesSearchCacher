//
//  iTunesSearchTerm.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

enum iTunesSearchTermKind: String {
    case song = "song"
    case book = "book"
    case album = "album"
    case musicVideo = "music-video"
    case pdfPodcast = "pdf podcast"
}

struct iTunesJSONResult {
    var artistId: Int32
    var trackId: Int32
    var artistName: String
    var trackName: String
    var collectionName: String
    var artistViewUrl: String
    var previewUrl: String
    var artworkUrl100: String
    var primaryGenreName: String
}

//@NSManaged var artistId: Int64
//@NSManaged var artistName: String
//@NSManaged var artistViewUrl: String

extension iTunesJSONResult: RawRepresentable {
    init?(rawValue: [String: AnyObject]) {
        
        if let _ = rawValue[RawArtistEntity.artistId] as? NSNumber,
            let _ = rawValue[RawArtistEntity.artistName] as? String,
            let _ = rawValue[RawArtistEntity.artistViewUrl] as? String,
            
            let _ = rawValue[RawCollectionEntity.artworkUrl] as? String,
            let _ = rawValue[RawCollectionEntity.collectionId] as? NSNumber,
            let _ = rawValue[RawCollectionEntity.collectionName] as? String,
            let _ = rawValue[RawCollectionEntity.collectionViewUrl] as? String,
            let _ = rawValue[RawCollectionEntity.primaryGenreName] as? String,
            
            let _ = rawValue[RawTrackEntity.previewUrl] as? String,
            let _ = rawValue[RawTrackEntity.trackId] as? NSNumber,
            let _ = rawValue[RawTrackEntity.trackName] as? String,
            let _ = rawValue[RawTrackEntity.trackNumber] as? NSNumber,
            
            let kind = rawValue["kind"] as? String where kind == "song" {
        
            
            return nil
            
            
        } else {
            return nil
        }
    }
    
    var rawValue: [String: AnyObject] {
        //TODO:
        return ["": ""]
    }
}