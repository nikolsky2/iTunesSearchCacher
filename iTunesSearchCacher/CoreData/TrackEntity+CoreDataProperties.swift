//
//  TrackEntity+CoreDataProperties.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 11/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension TrackEntity {

    @NSManaged var previewUrl: String
    @NSManaged var trackId: Int32
    @NSManaged var trackName: String
    @NSManaged var trackNumber: Int32
    @NSManaged var collection: CollectionEntity

}
