//
//  Trackable.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 15/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData
import UIKit

enum DownloadState: UInt {
    case NotDownloaded
    case Downloading
    case Downloaded
    
    var imageName: String {
        switch self {
        case .NotDownloaded:
            return "downloadFile"
        case .Downloading:
            return "downloadingFile"
        case .Downloaded:
            return "downloadedFile"
        }
    }
}

protocol TrackViewModel: class {
    var trackImage: UIImage? { get }
    var topString: String { get }
    var bottomString: String { get }
    var previewState: DownloadState { get }
}

extension TrackEntity: TrackViewModel {
    var trackImage: UIImage? {
        if let data = collection.artworkData {
            let image = UIImage(data: data)
            return image
        }
        
        return nil
    }
    
    var topString: String {
        return trackName + " (" + collection.collectionName + ")"
    }
    var bottomString: String {
        return "Song by " + collection.artist.artistName
    }
    
    var previewState: DownloadState {
        return preview.hasData ? .Downloaded : .NotDownloaded
    }
}

protocol Trackable: class {
    static func trackableId() -> String
}

extension TrackEntity: Trackable {
    static func trackableId() -> String {
        return "trackId"
    }
}

extension NSManagedObjectContext {
    func fetchWithIds<T: NSManagedObject where T: Trackable>(ids: [NSNumber]) -> [T] {
        
        let fetchRequest = NSFetchRequest(entityName: T.className)
        fetchRequest.relationshipKeyPathsForPrefetching = ["preview"]
        fetchRequest.predicate = NSPredicate(format: T.trackableId() + " IN %@", ids)
        let objects = try! self.executeFetchRequest(fetchRequest) as! [T]
        
        return objects
    }
}

