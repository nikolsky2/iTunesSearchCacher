//
//  RawResultsParser.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 9/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

class RawResultsParser {
    func parseResults(json: [String: AnyObject]) {
        
        if let rawResults = json["results"] as? [[String: AnyObject]] {
            
            let results = rawResults.flatMap ({
                (rawResult: [String : AnyObject]) -> iTunesJSONResult? in
                
                if let result = iTunesJSONResult(rawValue: rawResult) {
                    return result
                } else {
                    return nil
                }
            })
            print(results)
        }
        
        
        
    }
}