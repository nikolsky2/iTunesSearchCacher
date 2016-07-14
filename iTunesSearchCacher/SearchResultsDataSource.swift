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
        return itunesItems.count
    }
    
    subscript(index: Int) -> iTunesJSONResult {
        get {
            return itunesItems[index]
        }
    }
}

class SearchResultsDataSource: NSObject {
    
    weak var delegate: SearchResultsDataSourceDelegate?
    private var dataTask: NSURLSessionDataTask?
    
    //will notify
    private var fetchedResultsController: NSFetchedResultsController?
    
    private var itunesItems = [iTunesJSONResult]()
    private let mainContext: NSManagedObjectContext
    
    init(mainContext: NSManagedObjectContext) {
        self.mainContext = mainContext
        super.init()
    }
    
    func searchWithTerm(term: String) {
        
        fetchRequestWithTerm(term) { [unowned self] (rawDict: ([String : AnyObject])?) in
            if let json = rawDict {
                self.saveDataFromNetworkWith(json, completion: {
                    self.delegate?.didReceiveResults()
                })
            }
        }
    }
    
    typealias JSONResultItem = [String : AnyObject]
    
    private func isValidRawItem(rawValue: JSONResultItem) -> JSONResultItem? {
        if let _ = rawValue[RawArtistEntity.artistId] as? NSNumber,
            let _ = rawValue[RawArtistEntity.artistName] as? String,
            let _ = rawValue[RawArtistEntity.artistViewUrl] as? String,
            
            let _ = rawValue[RawCollectionEntity.artworkUrl] as? String,
            let _ = rawValue[RawCollectionEntity.collectionId] as? NSNumber,
            let _ = rawValue[RawCollectionEntity.collectionName] as? String,
            let _ = rawValue[RawCollectionEntity.collectionViewUrl] as? String,
            let _ = rawValue[RawCollectionEntity.primaryGenreName] as? String,
            
            let _ = rawValue[RawTrackEntity.previewUrl] as? String,
            let _ = rawValue[RawTrackEntity.trackId] as? NSNumber,
            let _ = rawValue[RawTrackEntity.trackName] as? String,
            let _ = rawValue[RawTrackEntity.trackNumber] as? NSNumber {
            return rawValue
        } else {
            return nil
        }
    }
    
    private func saveDataFromNetworkWith(json: JSONResultItem, completion: () -> ()) {
        
        if let rawResults = json["results"] as? [JSONResultItem] where rawResults.count > 0 {
            
            let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            privateContext.parentContext = mainContext
            privateContext.performBlock {
                
                // Valid data
                let validRawResults = rawResults.flatMap({ (rawValue: JSONResultItem) -> JSONResultItem? in
                    return self.isValidRawItem(rawValue)
                })
                
                //Track ids for fetching
                let rawTrackIds = validRawResults.flatMap({ (rawValue: JSONResultItem) -> NSNumber? in
                    if let trackId = rawValue[RawTrackEntity.trackId] as? NSNumber {
                        return trackId
                    } else {
                        return nil
                    }
                })
                
                //Collections ids for fetching
                let rawCollectionIds = Array(Set(validRawResults.flatMap({ (rawValue: JSONResultItem) -> NSNumber? in
                    if let trackId = rawValue[RawCollectionEntity.collectionId] as? NSNumber {
                        return trackId
                    } else {
                        return nil
                    }
                })))
                
                //Artists ids for fetching
                let rawArtistsIds = Array(Set(validRawResults.flatMap({ (rawValue: JSONResultItem) -> NSNumber? in
                    if let trackId = rawValue[RawArtistEntity.artistId] as? NSNumber {
                        return trackId
                    } else {
                        return nil
                    }
                })))
                
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
                
                
                var existingTrackEntities = Set(tracks)
                var existingCollectionEntities = Set(collections)
                var existingArtistEntities = Set(artists)
                
                var insertedTracks = 0
                var insertedCollections = 0
                var insertedArtists = 0
                var updatedCollections = 0
                var updatededArtists = 0
                
                for rawValue in validRawResults {
                    
                    let artistId = rawValue[RawArtistEntity.artistId] as! NSNumber
                    let artistName = rawValue[RawArtistEntity.artistName] as! String
                    let artistViewUrl = rawValue[RawArtistEntity.artistViewUrl] as! String
                    
                    let artworkUrl = rawValue[RawCollectionEntity.artworkUrl] as! String
                    let collectionId = rawValue[RawCollectionEntity.collectionId] as! NSNumber
                    let collectionName = rawValue[RawCollectionEntity.collectionName] as! String
                    let collectionViewUrl = rawValue[RawCollectionEntity.collectionViewUrl] as! String
                    let primaryGenreName = rawValue[RawCollectionEntity.primaryGenreName] as! String
                    
                    let previewUrl = rawValue[RawTrackEntity.previewUrl] as! String
                    let trackId = rawValue[RawTrackEntity.trackId] as! NSNumber
                    let trackName = rawValue[RawTrackEntity.trackName] as! String
                    let trackNumber = rawValue[RawTrackEntity.trackNumber] as! NSNumber
                    
                    // Track
                    
                    var trackEntity: TrackEntity!
                    let foundTracks = existingTrackEntities.filter{ $0.trackId == trackId.longLongValue }
                    if foundTracks.count > 0 {
                        
                        //skip existing objects
                        
                        continue
                    } else {
                        let track: TrackEntity = privateContext.createEntity()
                        trackEntity = track
                        existingTrackEntities.insert(trackEntity)
                        insertedTracks = insertedTracks + 1
                    }
                    
                    trackEntity.previewUrl = previewUrl
                    trackEntity.trackId = trackId.longLongValue
                    trackEntity.trackName = trackName
                    trackEntity.trackNumber = trackNumber.longLongValue
                    
                    // Collection
                    
                    var collectionEntity: CollectionEntity!
                    let foundCollections = existingCollectionEntities.filter{ $0.collectionId == collectionId.longLongValue }
                    if foundCollections.count > 0 {
                        collectionEntity = foundCollections[0]
                        updatedCollections = updatedCollections + 1
                    } else {
                        let collection: CollectionEntity = privateContext.createEntity()
                        collectionEntity = collection
                        existingCollectionEntities.insert(collectionEntity)
                        insertedCollections = insertedCollections + 1
                    }
                    
                    collectionEntity.artworkUrl = artworkUrl
                    collectionEntity.collectionId = collectionId.longLongValue
                    collectionEntity.collectionName = collectionName
                    collectionEntity.collectionViewUrl = collectionViewUrl
                    collectionEntity.primaryGenreName = primaryGenreName
                    
                    //Establish Collection - Tracks relationship
                    
                    var collectionTracks = Array(collectionEntity.tracks)
                    let collectionTracksIds = collectionTracks.map{ $0.trackId } as [Int64]
                    if collectionTracksIds.contains(trackEntity.trackId) == false {
                        collectionTracks.append(trackEntity)
                        collectionEntity.tracks = NSSet(array: collectionTracks)
                    }

                    // Artist
                    
                    var artistEntity: ArtistEntity!
                    let foundArtists = existingArtistEntities.filter{ $0.artistId == artistId.longLongValue }
                    if foundArtists.count > 0 {
                        artistEntity = foundArtists[0]
                        updatededArtists = updatededArtists + 1
                    } else {
                        let artist: ArtistEntity = privateContext.createEntity()
                        artistEntity = artist
                        existingArtistEntities.insert(artistEntity)
                        insertedArtists = insertedArtists + 1
                    }
                    
                    artistEntity.artistId = artistId.longLongValue
                    artistEntity.artistName = artistName
                    artistEntity.artistViewUrl = artistViewUrl
                    
                    //Establish Artist - Collections relationship
                    
                    var artistCollections = Array(artistEntity.collections)
                    let artistCollectionsIds = artistCollections.map{ $0.collectionId } as [Int64]
                    if artistCollectionsIds.contains(collectionEntity.collectionId) == false {
                        artistCollections.append(collectionEntity)
                        artistEntity.collections = NSSet(array: artistCollections)
                    }
                    
                    //Establish Collection - Artist relationship
                    collectionEntity.artist = artistEntity
                    
                    //Establish Track - Collection relationship
                    trackEntity.collection = collectionEntity
                }
                
                print("insertedTracks = \(insertedTracks)")
                print("insertedCollections = \(insertedCollections)")
                print("insertedArtists = \(insertedArtists)")
                print("updatedCollections = \(updatedCollections)")
                print("updatededArtists = \(updatededArtists)")
                print("----------------------------------------------")
                
                do {
                    try privateContext.save()
                    self.mainContext.performBlockAndWait {
                        do {
                            try self.mainContext.save()
                            completion()
                        } catch {
                            fatalError("Failure to save private context: \(error)")
                        }
                    }
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
        } else {
            print("no results")
            completion()
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
        }
        
        
        dataTask?.resume()
    }
    
}