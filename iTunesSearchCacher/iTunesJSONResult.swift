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
    
    var artistId: NSNumber
    var artistName: String
    var artistViewUrl: String
    
    var artworkUrl: String
    var collectionId: NSNumber
    var collectionName: String
    var collectionViewUrl: String
    var primaryGenreName: String
    
    var previewUrl: String
    var trackId: NSNumber
    var trackName: String
    var trackNumber: NSNumber
}

extension iTunesJSONResult: RawRepresentable {
    init?(rawValue: [String: AnyObject]) {
        
        if let artistId = rawValue[RawArtistEntity.artistId] as? NSNumber,
            let artistName = rawValue[RawArtistEntity.artistName] as? String,
            let artistViewUrl = rawValue[RawArtistEntity.artistViewUrl] as? String,
            
            let artworkUrl = rawValue[RawCollectionEntity.artworkUrl] as? String,
            let collectionId = rawValue[RawCollectionEntity.collectionId] as? NSNumber,
            let collectionName = rawValue[RawCollectionEntity.collectionName] as? String,
            let collectionViewUrl = rawValue[RawCollectionEntity.collectionViewUrl] as? String,
            let primaryGenreName = rawValue[RawCollectionEntity.primaryGenreName] as? String,
            
            let previewUrl = rawValue[RawTrackEntity.previewUrl] as? String,
            let trackId = rawValue[RawTrackEntity.trackId] as? NSNumber,
            let trackName = rawValue[RawTrackEntity.trackName] as? String,
            let trackNumber = rawValue[RawTrackEntity.trackNumber] as? NSNumber,
            
            let kind = rawValue["kind"] as? String where kind == "song" {
        
            self.previewUrl = previewUrl
            self.trackId = trackId
            self.trackName = trackName
            self.trackNumber = trackNumber
            
            self.artworkUrl = artworkUrl
            self.collectionId = collectionId
            self.collectionName = collectionName
            self.collectionViewUrl = collectionViewUrl
            self.primaryGenreName = primaryGenreName
            
            self.artistId = artistId
            self.artistName = artistName
            self.artistViewUrl = artistViewUrl
            
        } else {
            return nil
        }
    }
    
    var rawValue: [String: AnyObject] {
        return ["": ""]
    }
}