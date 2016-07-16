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
    func didReceiveResults()
}

extension SearchResultsDataSource {
    var numberOfItems: Int {
        return fetchedResultsController.sections?[0].numberOfObjects ?? 0
    }
    
    subscript(index: Int) -> TrackViewModel {
        get {
            let trackEntity = fetchedResultsController.objectAtIndexPath(NSIndexPath(forRow: index, inSection: 0)) as! TrackEntity
            return trackEntity
        }
    }
}

enum SearchMode {
    case All
    case Term(String)
}

class SearchResultsDataSource: NSObject {
    
    weak var delegate: SearchResultsDataSourceDelegate?
    private var dataTask: NSURLSessionDataTask?
    private let mainContext: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController!
    
    deinit {
        dataTask?.cancel()
    }
    
    init(mainContext: NSManagedObjectContext) {
        self.mainContext = mainContext
        super.init()
    }
    
    func searchWithMode(mode: SearchMode) {
        switch mode {
        case .All:
            break
        case .Term(let searchTerm):
            
            //Check local search term for this term
            
            //Fetch all search request
            let searchFetchRequest = NSFetchRequest(entityName: SearchEntity.className)
            let predicate = NSPredicate(format: "term == %@", searchTerm)
            searchFetchRequest.predicate = predicate
            let searches = try! mainContext.executeFetchRequest(searchFetchRequest) as! [SearchEntity]
            let foundSearchEntity = searches.filter{ $0.term == searchTerm }.first
            if let searchEnitiy = foundSearchEntity {
                
                let trackFetchRequest = NSFetchRequest(entityName: TrackEntity.className)
                let trackFetchPredicate = NSPredicate(format: "ANY searches == %@", searchEnitiy)
                trackFetchRequest.predicate = trackFetchPredicate
                trackFetchRequest.sortDescriptors = [TrackEntity.defaultSortDescriptor]
                
                fetchedResultsController = NSFetchedResultsController(fetchRequest: trackFetchRequest, managedObjectContext: mainContext, sectionNameKeyPath: nil, cacheName: nil)
                try! fetchedResultsController.performFetch()
                
                self.delegate?.didReceiveResults()
                
            } else {
                //perform network request
                fetchRequestWithTerm(searchTerm) { [unowned self] (rawDict: ([String : AnyObject])?) in
                    if let json = rawDict {
                        self.saveDataFromNetworkWith(searchTerm, json: json, completion: { (trackIds) in
                            
                            let trackFetchRequest = NSFetchRequest(entityName: TrackEntity.className)
                            trackFetchRequest.sortDescriptors = [TrackEntity.defaultSortDescriptor]
                            self.fetchedResultsController = NSFetchedResultsController(fetchRequest: trackFetchRequest, managedObjectContext: self.mainContext, sectionNameKeyPath: nil, cacheName: nil)
                            try! self.fetchedResultsController.performFetch()
                            
                            self.delegate?.didReceiveResults()
                        })
                    }
                }
            }
        }
    }
    
    typealias JSONResultItem = [String : AnyObject]
    
    private func saveDataFromNetworkWith(searchTerm: String, json: JSONResultItem, completion: (trackIds: [NSNumber]) -> ()) {
        
        if let rawResults = json["results"] as? [JSONResultItem] where rawResults.count > 0 {
            
            let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            privateContext.parentContext = mainContext
            privateContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
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
                    
                    //Fetch all search request
                    let searchFetchRequest = NSFetchRequest(entityName: SearchEntity.className)
                    let allSearches = try! privateContext.executeFetchRequest(searchFetchRequest) as! [SearchEntity]
                    
                    var searchEntity: SearchEntity!
                    let foundSearchEntity = allSearches.filter{ $0.term == searchTerm }.first
                    if foundSearchEntity != nil {
                        searchEntity = foundSearchEntity
                    } else {
                        let search: SearchEntity = privateContext.createEntity()
                        search.term = searchTerm
                        searchEntity = search
                    }
                    
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
                }
                
                stats.printResults()
                
                do {
                    try privateContext.save()
                    self.mainContext.performBlockAndWait {
                        do {
                            try self.mainContext.save()
                            completion(trackIds: rawTrackIds)
                        } catch {
                            fatalError("Failure to save private context: \(error)")
                        }
                    }
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
        } else {
            completion(trackIds: [])
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
            
            if error == nil {
                do {
                    if let d = data, rawDict = try NSJSONSerialization.JSONObjectWithData(d, options: []) as? [String: AnyObject] {
                        completionBlock(rawDict)
                    } else {
                        completionBlock(nil)
                    }
                }
                catch {
                    completionBlock(nil)
                }
            } else {
                print("error: \(error)")
            }
        }
        
        
        dataTask?.resume()
    }
    
    
    
}