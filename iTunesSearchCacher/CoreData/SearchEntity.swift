//
//  SearchEntity.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 15/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

class SearchEntity: NSManagedObject {
    func appendTrack(trackEntity: TrackEntity) -> Bool {
        if let tracks = self.tracks {
            var allTracks = Array(tracks) as! [TrackEntity]
            let tracksIds = allTracks.map{ $0.trackId } as [Int64]
            if tracksIds.contains(trackEntity.trackId) == false {
                allTracks.append(trackEntity)
                self.tracks = NSSet(array: allTracks)
            } else {
                return false
            }
        } else {
            self.tracks = NSSet(array: [trackEntity])
        }
        
        return true
    }
    
    static var defaultSortDescriptor: NSSortDescriptor {
        return NSSortDescriptor(key: "term", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))
    }
}
