//
//  SearchResultsDataSource.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

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

protocol SearchResultsDelegate: class {
    
    
}

class SearchResultsDataSource: NSObject {
    
    weak var delegate: SearchResultsDelegate?
    private var dataTask: NSURLSessionDataTask?
    
    func searchWithTerm(term: String) {
        let rawParser = RawSearchResultParser()
        fetchRequestWithTerm(term) { (rawDict: ([String : AnyObject])?) in
            if let json = rawDict {
                let iTunesItems = rawParser.parseResults(json)
                print(iTunesItems)
            }
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