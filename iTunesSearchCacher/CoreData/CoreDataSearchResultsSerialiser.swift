//
//  CoreDataSearchResultsFactory.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 27/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import CoreData

typealias JSONResultItem = [String : AnyObject]

class CoreDataSearchResultsSerialiser: NSObject {
    
    let mainContext: NSManagedObjectContext
    
    init(mainContext: NSManagedObjectContext) {
        self.mainContext = mainContext
        super.init()
    }
    
    func saveDataFromNetworkWith(searchTerm: String, json: JSONResultItem, completion: (trackIds: [NSNumber]) -> ()) {
        
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
                            stats.insertedTracks += 1
                        }
                        
                        trackEntity.trackId = item.trackId.longLongValue
                        trackEntity.trackName = item.trackName
                        trackEntity.trackNumber = item.trackNumber.longLongValue
                        
                        //AudioPreview
                        let preview: AudioPreviewEntity = privateContext.createEntity()
                        preview.track = trackEntity
                        preview.previewUrl = item.previewUrl
                        
                        searchEntity.appendTrack(trackEntity)
                        
                        // Collection
                        
                        var collectionEntity: CollectionEntity!
                        let foundCollections = recentCollection.existingCollectionEntities.filter{ $0.collectionId == item.collectionId.longLongValue }.first
                        if foundCollections != nil {
                            collectionEntity = foundCollections
                            stats.updatedCollections += 1
                        } else {
                            let collection: CollectionEntity = privateContext.createEntity()
                            collectionEntity = collection
                            recentCollection.existingCollectionEntities.append(collectionEntity)
                            stats.insertedCollections += 1
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
                            stats.updatededArtists += 1
                        } else {
                            let artist: ArtistEntity = privateContext.createEntity()
                            artistEntity = artist
                            recentCollection.existingArtistEntities.append(artistEntity)
                            stats.insertedArtists += 1
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
                        
                        trackEntity.preview = preview
                    }
                }
                
                stats.printResults()
                
                do {
                    try privateContext.save()
                    completion(trackIds: rawTrackIds)
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            }
        } else {
            completion(trackIds: [])
        }
    }
    
    
}