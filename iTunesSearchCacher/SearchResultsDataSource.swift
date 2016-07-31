//
//  SearchResultsDataSource.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

/*
 
 Overview
 
 The Search API allows you to place search fields in your website to search for content within the iTunes Store, App Store, iBooks Store and Mac App Store. You can search for a variety of content; including apps, iBooks, movies, podcasts, music, music videos, audiobooks, and TV shows.
 
 https://affiliate.itunes.apple.com/resources/documentation/itunes-store-web-service-search-api/
 
 */

private let fullyQualifiedURLString = "https://itunes.apple.com/search?"

struct iTunesParameterKey {
    static let term = "term"
    static let country = "country"
    static let media = "media"
    static let entity = "entity"
    static let limit = "limit"
}

struct EntitiesParameterKey {
    static let movie = "movie"
    static let podcast = "podcast"
    static let music = "music"
    static let musicVideo = "musicVideo"
    static let shortFilm = "shortFilm"
    static let all = "all"
}

protocol SearchResultsDataSourceDelegate: class {
    func didReloadResults()
    func didUpdateItemsAt(indexPaths: [NSIndexPath])
}

extension SearchResultsDataSource {
    var numberOfItems: Int {
        if let controller = tracksFetchResultsController {
            return controller.sections?[0].numberOfObjects ?? 0
        } else {
            return 0
        }
    }
    
    subscript(index: Int) -> TrackViewModel {
        get {
            let trackEntity = tracksFetchResultsController!.objectAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as! TrackEntity
            return trackEntity
        }
    }
}

enum SearchMode {
    case All
    case Term(String)
}

private let searchTermPropertyName = "term"

class SearchResultsDataSource: NSObject {
    
    weak var delegate: SearchResultsDataSourceDelegate?
    private var dataTask: NSURLSessionDataTask?
    private let mainContext: NSManagedObjectContext
    private let resultsSerialiser: CoreDataSearchResultsSerialiser
    
    private var tracksFetchResultsController: NSFetchedResultsController?
    private var collectionsFetchResultsController: NSFetchedResultsController?
    
    private let contextObserver: AnyObject
    
    deinit {
        dataTask?.cancel()
        
        print("Deinit of \(self)")
    }
    
    init(mainContext: NSManagedObjectContext) {
        self.mainContext = mainContext
        self.mainContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        contextObserver = NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: nil, queue: nil) {
            notification in
            
            mainContext.performBlock({ () -> Void in
                mainContext.mergeChangesFromContextDidSaveNotification(notification)
            })
        }
        
        resultsSerialiser = CoreDataSearchResultsSerialiser(mainContext: mainContext)
        
        super.init()
    }
    
    func searchWithMode(mode: SearchMode) {
        switch mode {
        case .All:
            break
        case .Term(let searchTerm):
            let foundSearchEntity = findSearchObjectWithSearchTerm(searchTerm)
            if let searchEnitiy = foundSearchEntity {
                performFetchRequestWith(searchEnitiy)
                self.delegate?.didReloadResults()
            } else {
                fetchRequestWithTerm(searchTerm) { [unowned self] (rawDict: ([String : AnyObject])?) in
                    if let json = rawDict {
                        self.resultsSerialiser.saveDataFromNetworkWith(searchTerm, json: json, completion: { (trackIds) in
                            dispatch_async(dispatch_get_main_queue()) {
                                let foundSearchEntity = self.findSearchObjectWithSearchTerm(searchTerm)
                                self.performFetchRequestWith(foundSearchEntity!)
                                self.delegate?.didReloadResults()
                            }
                        })
                    }
                }
            }
        }
    }
    
    private func findSearchObjectWithSearchTerm(searchTerm: String) -> SearchEntity? {
        let searchFetchRequest = NSFetchRequest(entityName: SearchEntity.className)
        let predicate = NSPredicate(format: "term == %@", searchTerm)
        searchFetchRequest.predicate = predicate
        let searches = try! mainContext.executeFetchRequest(searchFetchRequest) as! [SearchEntity]
        return searches.first
    }
    
    private func performFetchRequestWith(search: SearchEntity) {
        let trackFetchRequest = NSFetchRequest(entityName: TrackEntity.className)
        let trackFetchPredicate = NSPredicate(format: "ANY searches == %@", search)
        trackFetchRequest.predicate = trackFetchPredicate
        trackFetchRequest.sortDescriptors = [TrackEntity.defaultSortDescriptor]
        trackFetchRequest.relationshipKeyPathsForPrefetching = ["collection"]
        
        tracksFetchResultsController = NSFetchedResultsController(fetchRequest: trackFetchRequest, managedObjectContext: mainContext, sectionNameKeyPath: nil, cacheName: nil)
        tracksFetchResultsController!.delegate = self
        try! tracksFetchResultsController!.performFetch()
        
        let tracks = tracksFetchResultsController!.fetchedObjects as! [TrackEntity]
        let collectionFetchRequest = NSFetchRequest(entityName: CollectionEntity.className)
        let collectionFetchPredicate = NSPredicate(format: "ANY tracks IN %@", Set(tracks))
        collectionFetchRequest.predicate = collectionFetchPredicate
        collectionFetchRequest.sortDescriptors = [CollectionEntity.defaultSortDescriptor]
        
        collectionsFetchResultsController = NSFetchedResultsController(fetchRequest: collectionFetchRequest, managedObjectContext: mainContext, sectionNameKeyPath: nil, cacheName: nil)
        collectionsFetchResultsController!.delegate = self
        try! collectionsFetchResultsController!.performFetch()
    }
    
    private func fetchRequestWithTerm(term: String, completionBlock:([String: AnyObject])? -> ()) {
        dataTask?.cancel()
        
        let session = NSURLSession.sharedSession()
        
        let urlComponents = NSURLComponents(string: fullyQualifiedURLString)!
        let termQuery = NSURLQueryItem(name: iTunesParameterKey.term, value: term)
        let limitQuery = NSURLQueryItem(name: iTunesParameterKey.limit, value: "200")
        urlComponents.queryItems = [termQuery, limitQuery]
        
        dataTask = session.dataTaskWithRequest(NSURLRequest(URL: urlComponents.URL!)) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            
            typealias JSONResultItem = [String : AnyObject]
            var result: JSONResultItem? = nil
            
            if error == nil {
                do {
                    if let d = data, rawDict = try NSJSONSerialization.JSONObjectWithData(d, options: []) as? JSONResultItem {
                        result = rawDict
                    } else {
                        print("error: \(error)")
                    }
                }
                catch {
                    print("error: \(error)")
                }
            } else {
                print("error: \(error)")
            }
            
            dispatch_async(dispatch_get_main_queue()) { completionBlock(result) }
        }
        
        
        dataTask?.resume()
    }
}

extension SearchResultsDataSource: NSFetchedResultsControllerDelegate {
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch controller {
        case tracksFetchResultsController!:
            switch(type) {
            case .Update:
                self.delegate?.didUpdateItemsAt([indexPath!])
            default:
                break
            }
        case collectionsFetchResultsController!:
            
            let tracks = tracksFetchResultsController!.fetchedObjects as! [TrackEntity]
            let collection = anObject as! CollectionEntity
            let updatedTracks = tracks.filter { $0.collection.collectionId == collection.collectionId }
            let indices = updatedTracks.flatMap{ tracks.indexOf($0) }
            let indexPaths = indices.map{ NSIndexPath(forItem: $0, inSection: 0) }
            
            if !indexPaths.isEmpty {
                self.delegate?.didUpdateItemsAt(indexPaths)
            }
        default:
            break
        }
    }
}

extension SearchResultsDataSource: SearchResultsViewControllerDelegate {
    func didSelectTrackForDownloadingAt(indexPath: NSIndexPath) {
        mainContext.performBlock { 
            let track = self.tracksFetchResultsController!.objectAtIndexPath(indexPath) as! TrackEntity
            let preview = track.preview
            
            guard preview.needsDownload == false else { return }
            preview.needsDownload = true
            
            do {
                try self.mainContext.save()
            }
            catch {
                fatalError("failure to save context: \(error)")
            }
        }
    }
}





