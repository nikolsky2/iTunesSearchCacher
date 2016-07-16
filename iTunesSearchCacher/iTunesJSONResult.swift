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
            artistName = rawValue[RawArtistEntity.artistName] as? String,
            artistViewUrl = rawValue[RawArtistEntity.artistViewUrl] as? String,
            
            artworkUrl = rawValue[RawCollectionEntity.artworkUrl] as? String,
            collectionId = rawValue[RawCollectionEntity.collectionId] as? NSNumber,
            collectionName = rawValue[RawCollectionEntity.collectionName] as? String,
            collectionViewUrl = rawValue[RawCollectionEntity.collectionViewUrl] as? String,
            primaryGenreName = rawValue[RawCollectionEntity.primaryGenreName] as? String,
            
            previewUrl = rawValue[RawTrackEntity.previewUrl] as? String,
            trackId = rawValue[RawTrackEntity.trackId] as? NSNumber,
            trackName = rawValue[RawTrackEntity.trackName] as? String,
            trackNumber = rawValue[RawTrackEntity.trackNumber] as? NSNumber,
            
            kind = rawValue["kind"] as? String where kind == "song" {
        
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