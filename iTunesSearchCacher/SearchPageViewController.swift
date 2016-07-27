//
//  SearchPageViewController.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import UIKit

class SearchPageViewController: UIViewController {
    
    enum SegueType: String {
        case SearchResultsViewControllerId = "SearchResultsViewControllerId"
        case SearchTermsViewControllerSegueId = "SearchTermsViewControllerSegueId"
        case SearchPreselectedTermsSegueId = "SearchPreselectedTermsSegueId"
    }
    
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var searchButton: UIButton!
    @IBOutlet private weak var searchHistoryButton: UIButton!
    
    private var searchTermsViewController: SearchTermsViewController?
    private var preselectedSearchTerm: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchTextField.addTarget(self, action: #selector(SearchPageViewController.searchTextFieldDidChange), forControlEvents: .EditingChanged)
        
        searchButton.enabled = false
        //searchHistoryButton.enabled = false
    }
    
    @IBAction func settingsButtonDidTouch(sender: AnyObject) {
        AppManager.shared().fetchDataAgain()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        let segueType = SegueType(rawValue: segue.identifier!)!
        switch segueType {
        case .SearchResultsViewControllerId:
            let controller = segue.destinationViewController as! SearchResultsViewController
            controller.searchTerm = searchTextField.text
        case .SearchTermsViewControllerSegueId:
            
            // Fixes popover anchor centering issue in iOS 9 
            if let popoverPresentationController = segue.destinationViewController.popoverPresentationController, sourceView = sender as? UIView {
                popoverPresentationController.sourceRect = sourceView.bounds
            }
            
            let navController = segue.destinationViewController as! UINavigationController
            let controller = navController.topViewController as! SearchTermsViewController
            controller.delegate = self
            
            searchTermsViewController = controller
            
        case .SearchPreselectedTermsSegueId:
            let controller = segue.destinationViewController as! SearchResultsViewController
            controller.searchTerm = preselectedSearchTerm
        }
    }
    
    func searchTextFieldDidChange() {
        searchButton.enabled = searchTextField.text!.characters.count > 0
    }
}

extension SearchPageViewController: SearchTermsViewControllerDelegate {
    func didSelectRowWithTerm(term: String) {
        preselectedSearchTerm = term
        
        searchTermsViewController?.dismissViewControllerAnimated(true, completion: { [unowned self] in
            self.searchTermsViewController = nil
            self.performSegueWithIdentifier(SegueType.SearchPreselectedTermsSegueId.rawValue, sender: self)
        })
    }
}

