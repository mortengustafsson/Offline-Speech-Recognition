//
//  Colors.swift
//  Offline Speech Recognition
//
//  Created by Morten Gustafsson on 23/09/2020.
//  Copyright © 2020 mortengustafsson. All rights reserved.
//

import UIKit

extension UIColor {
    static func ConsoleViewColor() -> UIColor {
        if #available(iOS 13, *) {
            return UIColor.init { (trait) -> UIColor in
                // the color can be from your own color config struct as well.
                return trait.userInterfaceStyle == .dark ? UIColor.lightGray : UIColor.darkGray
            }
        }
        else { return UIColor.darkGray }
    }

    static func ConsoleViewTextColor() -> UIColor {
        if #available(iOS 13, *) {
            return UIColor.init { (trait) -> UIColor in
                // the color can be from your own color config struct as well.
                return trait.userInterfaceStyle == .dark ? UIColor.darkText : UIColor.lightText
            }
        }
        else { return UIColor.darkText }
    }

}
