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

private enum iTunesParameterKey: String {
    case term = "term"
    case country = "country"
    case media = "media"
    case entity = "entity"
}

private enum EntitiesParameterKey: String {
    case movie = "movie"
    case podcast = "podcast"
    case music = "music"
    case musicVideo = "musicVideo"
    case shortFilm = "shortFilm"
    case all = "all"
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
    private var fetchedResultsController: NSFetchedResultsController?
    private var itunesItems = [iTunesJSONResult]()
    
    func searchWithTerm(term: String) {
        let rawParser = RawSearchResultParser()
        fetchRequestWithTerm(term) { [unowned self] (rawDict: ([String : AnyObject])?) in
            if let json = rawDict {
                self.itunesItems = rawParser.parseResults(json)
            }
            
            self.delegate?.didReceiveResults()
        }
    }
    
    private func fetchRequestWithTerm(term: String, completionBlock:([String: AnyObject])? -> ()) {
        dataTask?.cancel()
        
        let session = NSURLSession.sharedSession()
        
        let urlComponents = NSURLComponents(string: fullyQualifiedURLString)!
        let termQuery = NSURLQueryItem(name: iTunesParameterKey.term.rawValue, value: term)
        urlComponents.queryItems = [termQuery]
        
        dataTask = session.dataTaskWithRequest(NSURLRequest(URL: urlComponents.URL!)) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
            
            do {
                if let d = data, rawDict = try NSJSONSerialization.JSONObjectWithData(d, options: []) as? [String: AnyObject] {
                    dispatch_async(dispatch_get_main_queue()) {
                        completionBlock(rawDict)
                    }
                }
            }
            catch {
                dispatch_async(dispatch_get_main_queue()) {
                    completionBlock(nil)
                }
            }
        }
        
        
        dataTask?.resume()
    }
    
}