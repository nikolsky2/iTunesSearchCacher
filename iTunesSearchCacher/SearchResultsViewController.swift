//
//  SearchResultsViewController.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import UIKit

protocol ReusableView: class {}
extension ReusableView where Self: UIView {
    static var reuseIdentifier: String {
        return String(self)
    }
}
extension UITableViewCell: ReusableView { }

class SearchResultsViewController: UIViewController {

    var searchTerm: String!
    var dataSource = SearchResultsDataSource()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = searchTerm
        
        dataSource.delegate = self
        dataSource.searchWithTerm(searchTerm)
    }
}

extension SearchResultsViewController: SearchResultsDelegate {
    
}
