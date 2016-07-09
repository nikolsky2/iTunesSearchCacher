//
//  Networking.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

/*
 
 Overview
 
 The Search API allows you to place search fields in your website to search for content within the iTunes Store, App Store, iBooks Store and Mac App Store. You can search for a variety of content; including apps, iBooks, movies, podcasts, music, music videos, audiobooks, and TV shows.
 
 https://affiliate.itunes.apple.com/resources/documentation/itunes-store-web-service-search-api/
 
 */

let fullyQualifiedURLString = "https://itunes.apple.com/search?"

enum iTunesParameterKey: String {
    case term = "term"
    case country = "country"
    case media = "media"
    case entity = "entity"
}

enum EntitiesParameterKey: String {
    case movie = "movie"
    case podcast = "podcast"
    case music = "music"
    case musicVideo = "musicVideo"
    case shortFilm = "shortFilm"
    case all = "all"
}

class Networking: NSObject {
    
    var dataTask: NSURLSessionDataTask!
    
    func fetchRequestWithTerm(term: String, completionBlock:([String: AnyObject])? -> ()) {
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
        
        
        dataTask.resume()
    }
    

    
    
}