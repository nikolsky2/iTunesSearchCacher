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
    @IBOutlet private weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var scrollView: UIScrollView!
    
    private var keyboardObserver: KeyboardObserver!
    private var didAutoscroll: Bool = false
    
    private var searchTermsViewController: SearchTermsViewController?
    private var preselectedSearchTerm: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchTextField.addTarget(self, action: #selector(SearchPageViewController.searchTextFieldDidChange), forControlEvents: .EditingChanged)
        
        searchButton.enabled = false
        
        keyboardObserver = KeyboardObserver()
        keyboardObserver.keyboardDidShowCompletionBlock = { [weak self] (keyboardHeight: CGFloat) -> () in
            if let strongSelf = self {
                strongSelf.bottomConstraint.constant = keyboardHeight
                strongSelf.scrollView.scrollIndicatorInsets.bottom = keyboardHeight
                
                let isFieldVisible = strongSelf.isViewOnScreen(strongSelf.searchTextField, keyboardHeight: keyboardHeight)

                if !isFieldVisible {
                    strongSelf.didAutoscroll = true
                    strongSelf.scrollView.setContentOffset(CGPoint(x: 0, y: 80), animated: true)
                }
            }
        }
        
        keyboardObserver.keyboardDidHideCompletionBlock = { [weak self] in
            if let strongSelf = self {
                strongSelf.bottomConstraint.constant = 0
                strongSelf.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: strongSelf.navBarIncludeStatusBarHeight, left: 0, bottom: 0, right: 0)
            }
        }
    }
    
    private func isViewOnScreen(view: UIView, keyboardHeight: CGFloat) -> Bool {
        let convertedRect = view.superview!.convertRect(view.frame, toView: self.view)
        
        let screenBounds = UIScreen.mainScreen().bounds
        let availableHeight = screenBounds.size.height - keyboardHeight - self.navBarIncludeStatusBarHeight
        let availableRect = CGRect(x: 0, y: self.navBarIncludeStatusBarHeight,
                                   width: screenBounds.size.width,
                                   height: availableHeight)
        
        return CGRectContainsRect(availableRect, convertedRect)
    }
    
    private var navBarIncludeStatusBarHeight: CGFloat {
        let statusBarHeight = UIApplication.sharedApplication().statusBarFrame.height
        let navBarHeight = navigationController?.navigationBar.frame.height
        return statusBarHeight + navBarHeight!
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        guard isViewLoaded() else {
            return
        }
        
        scrollView.scrollIndicatorInsets.top = navBarIncludeStatusBarHeight
        view.endEditing(true)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        keyboardObserver.registerKeyboardNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        keyboardObserver.unRegisterKeyboardNotifications()
    }
    
    
    
    @IBAction func settingsButtonDidTouch(sender: AnyObject) {
        
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
                popoverPresentationController.delegate = self
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
    
    func dismissPopoverController() {
        dismissViewControllerAnimated(true, completion: nil)
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

extension SearchPageViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if !didAutoscroll {
            view.endEditing(true)
        }
    }
    
    func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView)  {
        didAutoscroll = false
    }
}

extension SearchPageViewController: UIPopoverPresentationControllerDelegate {
    func presentationController(presentationController: UIPresentationController, willPresentWithAdaptiveStyle style: UIModalPresentationStyle, transitionCoordinator: UIViewControllerTransitionCoordinator?) {
        
        let navigationController = presentationController.presentedViewController as! UINavigationController
        let viewController = navigationController.viewControllers.first!
        
        if style == .FullScreen {
            let dismissButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: "") , style: UIBarButtonItemStyle.Plain,
                                                target: self, action: #selector(SearchPageViewController.dismissPopoverController))
            
            viewController.navigationItem.rightBarButtonItem = dismissButton
            
        } else {
            viewController.navigationItem.rightBarButtonItem = nil
        }
    }
}

