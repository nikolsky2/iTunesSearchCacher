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
        
        //TODO: check the cache otherwise cache the term
        
        fetchRequestWithTerm(term) { [unowned self] (rawDict: ([String : AnyObject])?) in
            if let json = rawDict {
                self.saveDataFromNetworkWith(json, completion: { 
                    self.delegate?.didReceiveResults()
                })
            }
        }
    }
    
    private func saveDataFromNetworkWith(json: [String : AnyObject], completion: () -> ()) {
        
        if let rawResults = json["results"] as? [[String: AnyObject]] where rawResults.count > 0 {
            
            //Collect ids for fetching
            let rawTrackIds = rawResults.flatMap({ (rawValue: [String : AnyObject]) -> NSNumber? in
                if let trackId = rawValue[RawTrackEntity.trackId] as? NSNumber {
                    return trackId
                } else {
                    return nil
                }
            })
            
            //Fetch DB for existing Ids
            let fetchRequest = NSFetchRequest(entityName: TrackEntity.className)
            fetchRequest.predicate = NSPredicate(format: "trackId IN %@", rawTrackIds)
            let trackEntities = try! self.mainContext.executeFetchRequest(fetchRequest) as! [TrackEntity]
            
            let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            privateContext.parentContext = mainContext
            privateContext.performBlock {
                
                let addToDBTrackIds = Set(rawTrackIds.map{$0.longLongValue}).subtract(Set(trackEntities.map{$0.trackId}))
                let onlyNonExistingRawResults = rawResults.filter({ (rawValue: [String : AnyObject]) -> Bool in
                    if let trackId = rawValue[RawTrackEntity.trackId] as? NSNumber {
                        return !addToDBTrackIds.contains(trackId.longLongValue)
                    }
                    
                    return false
                })
                
                var artists = [Int64 : ArtistEntity]()
                var collections = [Int64 : CollectionEntity]()
                
                for rawValue in onlyNonExistingRawResults {
                    if let artistId = rawValue[RawArtistEntity.artistId] as? NSNumber,
                        let artistName = rawValue[RawArtistEntity.artistName] as? String,
                        let artistViewUrl = rawValue[RawArtistEntity.artistViewUrl] as? String,
                        
                        let artworkUrl = rawValue[RawCollectionEntity.artworkUrl] as? String,
                        let collectionId = rawValue[RawCollectionEntity.collectionId] as? NSNumber,
                        let collectionName = rawValue[RawCollectionEntity.collectionName] as? String,
                        let collectionViewUrl = rawValue[RawCollectionEntity.collectionViewUrl] as? String,
                        let primaryGenreName = rawValue[RawCollectionEntity.primaryGenreName] as? String,
                        
                        let previewUrl = rawValue[RawTrackEntity.previewUrl] as? String,
                        let trackId = rawValue[RawTrackEntity.trackId] as? NSNumber,
                        let trackName = rawValue[RawTrackEntity.trackName] as? String,
                        let trackNumber = rawValue[RawTrackEntity.trackNumber] as? NSNumber {
                        
                        // Track
                        
                        let trackEntity: TrackEntity = privateContext.createEntity()
                        trackEntity.previewUrl = previewUrl
                        trackEntity.trackId = trackId.longLongValue
                        trackEntity.trackName = trackName
                        trackEntity.trackNumber = trackNumber.longLongValue
                        
                        // Collection
                        
                        var collectionEntity: CollectionEntity!
                        if let collection = collections[collectionId.longLongValue] {
                            collectionEntity = collection
                        } else {
                            let collection: CollectionEntity = privateContext.createEntity()
                            collection.artworkUrl = artworkUrl
                            collection.collectionId = collectionId.longLongValue
                            collection.collectionName = collectionName
                            collection.collectionViewUrl = collectionViewUrl
                            collection.primaryGenreName = primaryGenreName
                            collectionEntity = collection
                            collections[collection.collectionId] = collectionEntity
                        }
                        
                        var tracks = Array(collectionEntity.tracks)
                        tracks.append(trackEntity)
                        collectionEntity.tracks = NSSet(array: tracks)
                        
                        // Artist
                        
                        var artistEntity: ArtistEntity!
                        if let artist = artists[artistId.longLongValue] {
                            artistEntity = artist
                        } else {
                            let artist: ArtistEntity = privateContext.createEntity()
                            artist.artistId = artistId.longLongValue
                            artist.artistName = artistName
                            artist.artistViewUrl = artistViewUrl
                        }
                        
                        var collections = Array(artistEntity.collections)
                        collections.append(collectionEntity)
                        artistEntity.collections = NSSet(array: collections)
                    }
                }
                
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