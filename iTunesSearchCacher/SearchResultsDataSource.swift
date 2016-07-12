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
                self.saveDataFromNetworkWith(json)
            }
            
            //            dispatch_async(dispatch_get_main_queue()) {
            //                self.delegate?.didReceiveResults()
            //            }
        }
    }
    
    private func saveDataFromNetworkWith(json: [String : AnyObject]) {
        
        if let rawResults = json["results"] as? [[String: AnyObject]] where rawResults.count > 0 {
            
            let privateMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            privateMOC.parentContext = mainContext
            privateMOC.performBlock {
                
                let artists = [Int32 : ArtistEntity]()
                let collections = [Int32 : CollectionEntity]()
                
                for rawValue in rawResults {
                    
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
                        
                        var artistEntity: ArtistEntity!
                        if let artist = artists[artistId.intValue] {
                            artistEntity = artist
                        } else {
                            let artist: ArtistEntity = self.mainContext.createEntity()
                            artist.artistId = artistId.intValue
                            artist.artistName = artistName
                            artist.artistViewUrl = artistViewUrl
                            artistEntity = artist
                        }
                        
                        var collectionEntity: CollectionEntity!
                        if let collection = collections[collectionId.intValue] {
                            collectionEntity = collection
                        } else {
                            let collection: CollectionEntity = self.mainContext.createEntity()
                            collection.artworkUrl = artworkUrl
                            collection.collectionId = collectionId.intValue
                            collection.collectionName = collectionName
                            collection.collectionViewUrl = collectionViewUrl
                            collection.primaryGenreName = primaryGenreName
                            collection.artist = artistEntity
                            collectionEntity = collection
                        }
                        var collections = Array(artistEntity.collections)
                        collections.append(collectionEntity)
                        artistEntity.collections = NSSet(array: collections)
                        
                        let trackEntity: TrackEntity = self.mainContext.createEntity()
                        trackEntity.previewUrl = previewUrl
                        trackEntity.trackId = trackId.intValue
                        trackEntity.trackName = trackName
                        trackEntity.trackNumber = trackNumber.intValue
                        
                        var tracks = Array(collectionEntity.tracks)
                        tracks.append(trackEntity)
                        collectionEntity.tracks = NSSet(array: tracks)
                        
                    } else {
                        print("this item is invalid")
                        break
                    }
                }
                
                do {
                    try privateMOC.save()
                    self.mainContext.performBlockAndWait {
                        do {
                            try self.mainContext.save()
                        } catch {
                            fatalError("Failure to save context: \(error)")
                        }
                    }
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
            
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