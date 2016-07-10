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
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var contentTableView: UITableView!
    @IBOutlet private weak var loadingView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = searchTerm
        
        dataSource.delegate = self
        dataSource.searchWithTerm(searchTerm)
        
        contentView.alpha = 0
        loadingView.alpha = 1
    }
}

extension SearchResultsViewController: SearchResultsDataSourceDelegate {
    func didReceiveResults() {
        
        UIView.animateWithDuration(0.3) { [unowned self] in
            if self.dataSource.numberOfItems > 0 {
                self.contentView.alpha = 1
                self.loadingView.alpha = 0
            } else {
                self.contentView.alpha = 0
                self.loadingView.alpha = 1
            }
        }
    }
}
