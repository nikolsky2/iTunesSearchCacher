//
//  SearchEntity+CoreDataProperties.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 15/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension SearchEntity {

    @NSManaged var term: String
    @NSManaged var tracks: NSSet?

}
