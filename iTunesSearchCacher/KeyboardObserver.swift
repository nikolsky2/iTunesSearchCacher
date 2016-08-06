//
//  KeyboardObserver.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 3/08/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import UIKit

class KeyboardObserver: NSObject {
    
    var keyboardDidShowCompletionBlock: ((keyboardHeight: CGFloat) -> ())?
    var keyboardDidHideCompletionBlock: (() -> ())?
    
    deinit {
        unRegisterKeyboardNotifications()
    }
    
    func registerKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardDidShowNotification, object: nil, queue: nil) { (notification: NSNotification) in
            
            var keyboardHeight: CGFloat = 0
            if let userInfo = notification.userInfo, keyboardSize = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
                    keyboardHeight = keyboardSize.height
            }
            self.keyboardDidShowCompletionBlock?(keyboardHeight: keyboardHeight)
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardDidHideNotification, object: nil, queue: nil) { [unowned self] (notification: NSNotification) in
            
            self.keyboardDidHideCompletionBlock?()
        }
    }
    
    func unRegisterKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}