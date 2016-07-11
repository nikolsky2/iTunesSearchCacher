//
//  CollectionEntity+CoreDataProperties.swift
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

extension CollectionEntity {

    @NSManaged var artworkUrl: String
    @NSManaged var collectionId: Int32
    @NSManaged var collectionName: String
    @NSManaged var collectionViewUrl: String
    @NSManaged var primaryGenreName: String
    @NSManaged var artist: ArtistEntity
    @NSManaged var tracks: NSSet

}
