//
//  NSObject+ClassName.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 12/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation

extension NSObject {
    class var className: String{
        return NSStringFromClass(self).componentsSeparatedByString(".").last!
    }
    
    var className: String{
        return NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last!
    }
}