//
//  AudioPreviewEntity.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 27/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData


class AudioPreviewEntity: NSManagedObject {
    static var defaultSortDescriptor: NSSortDescriptor {
        return NSSortDescriptor(key: "hasData", ascending: false)
    }
}
