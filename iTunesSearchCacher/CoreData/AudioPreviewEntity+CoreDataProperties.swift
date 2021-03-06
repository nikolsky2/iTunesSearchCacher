//
//  AudioPreviewEntity+CoreDataProperties.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 30/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension AudioPreviewEntity {

    @NSManaged var hasPreviewData: Bool
    @NSManaged var previewData: NSData?
    @NSManaged var previewUrl: String
    @NSManaged var needsDownload: Bool
    @NSManaged var track: TrackEntity

}
