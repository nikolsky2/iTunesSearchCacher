//
//  AudioPreviewEntity+CoreDataProperties.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 27/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension AudioPreviewEntity {

    @NSManaged var previewData: NSData?
    @NSManaged var hasData: Bool
    @NSManaged var track: TrackEntity

}
