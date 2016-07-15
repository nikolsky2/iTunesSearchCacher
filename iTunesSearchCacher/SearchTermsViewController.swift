//
//  SearchTermsViewController.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 15/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class SearchTableViewCell: UITableViewCell {
    
}

protocol SearchTermsViewControllerDelegate: class {
    func didSelectRowWithTerm(term: String)
}

class SearchTermsViewController: UIViewController {

    lazy var context: NSManagedObjectContext = {
        return AppManager.shared().mainContext
    }()
    
    weak var delegate: SearchTermsViewControllerDelegate?
    
    private var searchTerms: [SearchEntity]!
    
    @IBOutlet private weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        //Fetch all search history
        let fetchRequest = NSFetchRequest(entityName: SearchEntity.className)
        let sortDescriptor = NSSortDescriptor(key: "term", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        searchTerms = try! context.executeFetchRequest(fetchRequest) as! [SearchEntity]
    }
}

extension SearchTermsViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchTerms.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(SearchTableViewCell.className, forIndexPath: indexPath) as! SearchTableViewCell
        
        let searchTerm = searchTerms[indexPath.item]
        cell.textLabel?.text = searchTerm.term
        
        return cell
    }
}

extension SearchTermsViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let searchTerm = searchTerms[indexPath.item]
        delegate?.didSelectRowWithTerm(searchTerm.term)
    }
    
}