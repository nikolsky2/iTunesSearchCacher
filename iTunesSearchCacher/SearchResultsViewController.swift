//
//  SearchResultsViewController.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import UIKit
import CoreData

protocol ReusableView: class {}
extension ReusableView where Self: UIView {
    static var reuseIdentifier: String {
        return String(self)
    }
}
extension UITableViewCell: ReusableView { }

class TrackTableViewCell: UITableViewCell {
    @IBOutlet private weak var thumbnailView: UIImageView!
    @IBOutlet private weak var topLabel: UILabel!
    @IBOutlet private weak var bottomLabel: UILabel!
}

class SearchResultsViewController: UIViewController {

    var searchTerm: String!
    private var dataSource = SearchResultsDataSource(mainContext: AppManager.shared().mainContext)
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var contentTableView: UITableView!
    @IBOutlet private weak var loadingView: UIView!
    @IBOutlet private weak var noDataView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = searchTerm
        
        dataSource.delegate = self
        dataSource.searchWithMode(SearchMode.Term(searchTerm))
        
        noDataView.alpha = 0
        contentView.alpha = 0
        loadingView.alpha = 1
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadData()
    }
    
    private func reloadData() {
        contentTableView.reloadData()
        
        UIView.animateWithDuration(0.3) { [unowned self] in
            if self.dataSource.numberOfItems > 0 {
                self.contentView.alpha = 1
                self.loadingView.alpha = 0
            } else {
                self.contentView.alpha = 0
                self.loadingView.alpha = 0
                self.noDataView.alpha = 1
            }
        }
    }
}

extension SearchResultsViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.numberOfItems
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(TrackTableViewCell.className, forIndexPath: indexPath) as! TrackTableViewCell
        
        cell.topLabel.text = dataSource[indexPath.row].topString
        cell.bottomLabel.text = dataSource[indexPath.row].bottomString
        
        return cell
    }
}

extension SearchResultsViewController: UITableViewDelegate {
    
}

extension SearchResultsViewController: SearchResultsDataSourceDelegate {
    func didReceiveResults() {
        reloadData()
    }
}
