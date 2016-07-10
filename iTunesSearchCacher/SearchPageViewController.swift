//
//  SearchPageViewController.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import UIKit

class SearchPageViewController: UIViewController {
    
    enum Segues: String {
        case SearchResultsViewControllerId = "SearchResultsViewControllerId"
    }
    
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var searchButton: UIButton!
    @IBOutlet private weak var searchHistoryButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchTextField.addTarget(self, action: #selector(SearchPageViewController.searchTextFieldDidChange), forControlEvents: .EditingChanged)
        
        searchButton.enabled = false
        searchHistoryButton.enabled = false
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == Segues.SearchResultsViewControllerId.rawValue {
            let controller = segue.destinationViewController as! SearchResultsViewController
            
            
            
            controller.searchTerm = searchTextField.text
        }
    }
    
    func searchTextFieldDidChange() {
        searchButton.enabled = searchTextField.text!.characters.count > 0
    }

}

