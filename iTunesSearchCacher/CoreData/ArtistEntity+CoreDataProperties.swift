//
//  ArtistEntity+CoreDataProperties.swift
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

extension ArtistEntity {

    @NSManaged var artistId: Int64
    @NSManaged var artistName: String
    @NSManaged var artistViewUrl: String
    @NSManaged var collections: NSSet

}
