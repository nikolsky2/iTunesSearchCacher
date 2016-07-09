//
//  iTunesSearchTerm.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

enum iTunesJSONResultKey: String {
    case kind = "kind"
    case artistId = "artistId"
    case trackId = "trackId"
    
    case artistName = "artistName"
    case trackName = "trackName"
    case collectionName = "collectionName"
    
    case artistViewUrl = "artistViewUrl"
    case previewUrl = "previewUrl"
    case artworkUrl100 = "artworkUrl100"
    
    case primaryGenreName = "primaryGenreName"
}

enum iTunesSearchTermKind: String {
    case song = "song"
    case book = "book"
    case album = "album"
    case musicVideo = "music-video"
    case pdfPodcast = "pdf podcast"
}

struct iTunesJSONResult {
    var kind: iTunesSearchTermKind
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

extension iTunesJSONResult: RawRepresentable {
    init?(rawValue: [String: AnyObject]) {
        if let rawKind = rawValue[iTunesJSONResultKey.kind.rawValue] as? String , let kind = iTunesSearchTermKind(rawValue: rawKind),
            let artistId = rawValue[iTunesJSONResultKey.artistId.rawValue] as? NSNumber,
            let trackId = rawValue[iTunesJSONResultKey.trackId.rawValue] as? NSNumber,
            
            let artistName = rawValue[iTunesJSONResultKey.artistName.rawValue] as? String,
            let trackName = rawValue[iTunesJSONResultKey.trackName.rawValue] as? String,
            let collectionName = rawValue[iTunesJSONResultKey.collectionName.rawValue] as? String,
            
            let artistViewUrl = rawValue[iTunesJSONResultKey.artistViewUrl.rawValue] as? String,
            let previewUrl = rawValue[iTunesJSONResultKey.previewUrl.rawValue] as? String,
            let artworkUrl100 = rawValue[iTunesJSONResultKey.artworkUrl100.rawValue] as? String,
            
            let primaryGenreName = rawValue[iTunesJSONResultKey.primaryGenreName.rawValue] as? String
        {
            self.kind = kind
            self.artistId = artistId.intValue
            self.trackId = trackId.intValue
            
            self.artistName = artistName
            self.trackName = trackName
            self.collectionName = collectionName
            
            self.artistViewUrl = artistViewUrl
            self.previewUrl = previewUrl
            self.artworkUrl100 = artworkUrl100
            
            self.primaryGenreName = primaryGenreName
        } else {
            return nil
        }
    }
    
    var rawValue: [String: AnyObject] {
        //TODO:
        return ["": ""]
    }
}