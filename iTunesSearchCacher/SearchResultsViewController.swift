//
//  SearchResultsViewController.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import UIKit

protocol SearchResultsDataSource: class {
    
    
}

protocol SearchResultsDelegate: class {
    
    
}

class SearchResultsViewController: UIViewController {

    var searchTerm: String!
    weak var searchResultsDataSource: SearchResultsDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = searchTerm
        
        //startRequest here
        
    
    }
}

extension SearchResultsViewController: SearchResultsDelegate {
    
}
