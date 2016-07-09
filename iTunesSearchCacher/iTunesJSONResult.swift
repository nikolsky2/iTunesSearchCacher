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
    let kind: iTunesSearchTermKind
    let artistId: Int32
    let trackId: Int32
    
    let artistName: String
    let trackName: String
    let collectionName: String
    
    let artistViewUrl: String
    let previewUrl: String
    let artworkUrl100: String
    
    let primaryGenreName: String
}

extension iTunesJSONResult: RawRepresentable {
    init?(rawValue: [String: AnyObject]) {
        
        self.kind = .song
        artistId = 0
        trackId = 0
        
        artistName = ""
        trackName = ""
        collectionName = ""
        
        artistViewUrl = ""
        previewUrl = ""
        artworkUrl100 = ""
        
        primaryGenreName = ""
    }
    
    var rawValue: [String: AnyObject] {
        return ["": ""]
    }
}