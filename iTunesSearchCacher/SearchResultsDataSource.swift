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
                
                for rawValue in onlyNonExistingRawResults {
                    let _ = TrackEntity.create(rawValue, context: privateContext)
                    let _ = CollectionEntity.create(rawValue, context: privateContext)
                    let _ = CollectionEntity.create(rawValue, context: privateContext)
                }
                
                do {
                    try privateContext.save()
                    self.mainContext.performBlockAndWait {
                        do {
                            try self.mainContext.save()
                            completion()
                        } catch {
                            fatalError("Failure to save context: \(error)")
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