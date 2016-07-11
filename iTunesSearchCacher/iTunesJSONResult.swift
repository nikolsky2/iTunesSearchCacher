//
//  iTunesSearchTerm.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

struct iTunesJSONResultKey {
    static let kind = "kind"
    static let artistId = "artistId"
    static let trackId = "trackId"
    static let artistName = "artistName"
    static let trackName = "trackName"
    static let collectionName = "collectionName"
    static let artistViewUrl = "artistViewUrl"
    static let previewUrl = "previewUrl"
    static let artworkUrl100 = "artworkUrl100"
    static let primaryGenreName = "primaryGenreName"
}

enum iTunesSearchTermKind: String {
    case song = "song"
    case book = "book"
    case album = "album"
    case musicVideo = "music-video"
    case pdfPodcast = "pdf podcast"
}

//TODO: Convert it to NSManagedObject

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
        if let rawKind = rawValue[iTunesJSONResultKey.kind] as? String , let kind = iTunesSearchTermKind(rawValue: rawKind),
            let artistId = rawValue[iTunesJSONResultKey.artistId] as? NSNumber,
            let trackId = rawValue[iTunesJSONResultKey.trackId] as? NSNumber,
            
            let artistName = rawValue[iTunesJSONResultKey.artistName] as? String,
            let trackName = rawValue[iTunesJSONResultKey.trackName] as? String,
            let collectionName = rawValue[iTunesJSONResultKey.collectionName] as? String,
            
            let artistViewUrl = rawValue[iTunesJSONResultKey.artistViewUrl] as? String,
            let previewUrl = rawValue[iTunesJSONResultKey.previewUrl] as? String,
            let artworkUrl100 = rawValue[iTunesJSONResultKey.artworkUrl100] as? String,
            
            let primaryGenreName = rawValue[iTunesJSONResultKey.primaryGenreName] as? String
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