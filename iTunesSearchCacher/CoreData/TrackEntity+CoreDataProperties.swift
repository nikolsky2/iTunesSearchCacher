//
//  TrackEntity+CoreDataProperties.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 29/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension TrackEntity {

    @NSManaged var trackId: Int64
    @NSManaged var trackName: String
    @NSManaged var trackNumber: Int64
    @NSManaged var collection: CollectionEntity
    @NSManaged var preview: AudioPreviewEntity
    @NSManaged var searches: NSSet?

}
