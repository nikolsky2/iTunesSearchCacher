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
    
    typealias JSONResultItem = [String : AnyObject]
    
    weak var delegate: SearchResultsDataSourceDelegate?
    private var dataTask: NSURLSessionDataTask?
    private let mainContext: NSManagedObjectContext
    
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
                        self.saveDataFromNetworkWith(searchTerm, json: json, completion: { (trackIds) in
                            let foundSearchEntity = self.findSearchObjectWithSearchTerm(searchTerm)
                            self.performFetchRequestWith(foundSearchEntity!)
                            self.delegate?.didReloadResults()
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
    
    private func saveDataFromNetworkWith(searchTerm: String, json: JSONResultItem, completion: (trackIds: [NSNumber]) -> ()) {
        
        if let rawResults = json["results"] as? [JSONResultItem] where rawResults.count > 0 {
            
            let privateContext = mainContext.createBackgroundContext()
            privateContext.performBlock {
                
                struct LocalCollection {
                    var existingTrackEntities: [TrackEntity]
                    var existingCollectionEntities: [CollectionEntity]
                    var existingArtistEntities: [ArtistEntity]
                }
                
                var recentCollection = LocalCollection(existingTrackEntities: [], existingCollectionEntities: [], existingArtistEntities: [])
                
                // Valid data
                let validResults = rawResults.flatMap{ iTunesJSONResult(rawValue: $0) }
                
                //Track ids for fetching
                let rawTrackIds = validResults.map{ $0.trackId }
                
                //Collections ids for fetching
                let rawCollectionIds = Array(Set(validResults.map{ $0.collectionId }))
                
                //Artists ids for fetching
                let rawArtistsIds = Array(Set(validResults.map{ $0.artistId }))
                
                struct Stats {
                    var insertedTracks = 0
                    var insertedCollections = 0
                    var insertedArtists = 0
                    var updatedCollections = 0
                    var updatededArtists = 0
                    
                    func printResults() {
                        print("insertedTracks = \(insertedTracks)")
                        print("insertedCollections = \(insertedCollections)")
                        print("insertedArtists = \(insertedArtists)")
                        print("updatedCollections = \(updatedCollections)")
                        print("updatededArtists = \(updatededArtists)")
                        print("----------------------------------------------")
                    }
                }
                
                var stats = Stats()

                if validResults.count > 0 {
                    
                    //Fetch all tracks
                    let trackFetchRequest = NSFetchRequest(entityName: TrackEntity.className)
                    trackFetchRequest.predicate = NSPredicate(format: "trackId IN %@", rawTrackIds)
                    let tracks = try! privateContext.executeFetchRequest(trackFetchRequest) as! [TrackEntity]
                    
                    //Fetch all collections
                    let collectionFetchRequest = NSFetchRequest(entityName: CollectionEntity.className)
                    collectionFetchRequest.predicate = NSPredicate(format: "collectionId IN %@", rawCollectionIds)
                    let collections = try! privateContext.executeFetchRequest(collectionFetchRequest) as! [CollectionEntity]
                    
                    //Fetch all artists
                    let artistFetchRequest = NSFetchRequest(entityName: ArtistEntity.className)
                    artistFetchRequest.predicate = NSPredicate(format: "artistId IN %@", rawArtistsIds)
                    let artists = try! privateContext.executeFetchRequest(artistFetchRequest) as! [ArtistEntity]
                    
                    recentCollection.existingTrackEntities.appendContentsOf(tracks)
                    recentCollection.existingCollectionEntities.appendContentsOf(collections)
                    recentCollection.existingArtistEntities.appendContentsOf(artists)
                    
                    let searchEntity: SearchEntity = privateContext.createEntity()
                    searchEntity.term = searchTerm
                    
                    for item in validResults {
                        
                        // Track
                        var trackEntity: TrackEntity!
                        let foundTracks = recentCollection.existingTrackEntities.filter{ $0.trackId == item.trackId.longLongValue }.first
                        if foundTracks != nil {
                            
                            //skip existing objects
                            
                            continue
                        } else {
                            let track: TrackEntity = privateContext.createEntity()
                            trackEntity = track
                            recentCollection.existingTrackEntities.append(trackEntity)
                            stats.insertedTracks = stats.insertedTracks + 1
                        }
                        
                        trackEntity.previewUrl = item.previewUrl
                        trackEntity.trackId = item.trackId.longLongValue
                        trackEntity.trackName = item.trackName
                        trackEntity.trackNumber = item.trackNumber.longLongValue
                        
                        searchEntity.appendTrack(trackEntity)
                        
                        // Collection
                        
                        var collectionEntity: CollectionEntity!
                        let foundCollections = recentCollection.existingCollectionEntities.filter{ $0.collectionId == item.collectionId.longLongValue }.first
                        if foundCollections != nil {
                            collectionEntity = foundCollections
                            stats.updatedCollections = stats.updatedCollections + 1
                        } else {
                            let collection: CollectionEntity = privateContext.createEntity()
                            collectionEntity = collection
                            recentCollection.existingCollectionEntities.append(collectionEntity)
                            stats.insertedCollections = stats.insertedCollections + 1
                        }
                        
                        collectionEntity.artworkUrl = item.artworkUrl
                        collectionEntity.collectionId = item.collectionId.longLongValue
                        collectionEntity.collectionName = item.collectionName
                        collectionEntity.collectionViewUrl = item.collectionViewUrl
                        collectionEntity.primaryGenreName = item.primaryGenreName
                        
                        //Establish Collection - Tracks relationship
                        collectionEntity.appendTrack(trackEntity)
                        
                        // Artist
                        
                        var artistEntity: ArtistEntity!
                        let foundArtists = recentCollection.existingArtistEntities.filter{ $0.artistId == item.artistId.longLongValue }.first
                        if foundArtists != nil {
                            artistEntity = foundArtists
                            stats.updatededArtists = stats.updatededArtists + 1
                        } else {
                            let artist: ArtistEntity = privateContext.createEntity()
                            artistEntity = artist
                            recentCollection.existingArtistEntities.append(artistEntity)
                            stats.insertedArtists = stats.insertedArtists + 1
                        }
                        
                        artistEntity.artistId = item.artistId.longLongValue
                        artistEntity.artistName = item.artistName
                        artistEntity.artistViewUrl = item.artistViewUrl
                        
                        //Establish Artist - Collections relationship
                        artistEntity.appendCollection(collectionEntity)
                        
                        //Establish Collection - Artist relationship
                        collectionEntity.artist = artistEntity
                        
                        //Establish Track - Collection relationship
                        trackEntity.collection = collectionEntity
                    }
                    
                    let allColections = recentCollection.existingCollectionEntities.map{ $0.collectionId }
                    let uColections = Set(allColections)
                    
                    assert(allColections.count == uColections.count, "collections are unique")
                }
                
                stats.printResults()
                
                do {
                    try privateContext.save()
                    dispatch_async(dispatch_get_main_queue()) { completion(trackIds: rawTrackIds) }
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue()) { completion(trackIds: []) }
            
        }
    }
    
    private func fetchRequestWithTerm(term: String, completionBlock:([String: AnyObject])? -> ()) {
        dataTask?.cancel()
        
        let session = NSURLSession.sharedSession()
        
        let urlComponents = NSURLComponents(string: fullyQualifiedURLString)!
        let termQuery = NSURLQueryItem(name: iTunesParameterKey.term, value: term)
        let limitQuery = NSURLQueryItem(name: iTunesParameterKey.limit, value: "200")
        urlComponents.queryItems = [termQuery, limitQuery]
        
        dataTask = session.dataTaskWithRequest(NSURLRequest(URL: urlComponents.URL!)) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            
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






