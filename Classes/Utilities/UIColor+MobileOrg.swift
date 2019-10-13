//
//  UIColor+MobileOrg.swift
//  MobileOrg
//
//  Created by Artem Loenko on 07/10/2019.
//  Copyright © 2019 Artem Loenko.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

import Foundation

extension UIColor {

    @objc(mo_textColor)
    static let mo_text: UIColor = {
        if #available(iOS 13, *) { return .label }
        return .black
    }()

    @objc(mo_secondaryTextColor)
    static let mo_secondaryText: UIColor = {
        if #available(iOS 13, *) { return .secondaryLabel }
        return .mo_darkGray
    }()

    @objc(mo_tertiaryTextColor)
    static let mo_tertiaryText: UIColor = {
        if #available(iOS 13, *) { return .tertiaryLabel }
        return .mo_gray
    }()

    @objc(mo_backgroundColor)
    static let mo_background: UIColor = {
        if #available(iOS 13, *) { return .systemBackground }
        return .white
    }()

    @objc(mo_grayColor)
    static let mo_gray: UIColor = {
        if #available(iOS 13, *) { return .systemGray2 }
        return .gray
    }()

    @objc(mo_darkGrayColor)
    static let mo_darkGray: UIColor = {
        if #available(iOS 13, *) { return .systemGray }
        return .darkGray
    }()

    @objc(mo_lightGrayColor)
    static let mo_lightGray: UIColor = {
        if #available(iOS 13, *) { return .systemGray3 }
        return .lightGray
    }()

    @objc(mo_lightLightGrayColor)
    static let mo_lightLightGray: UIColor = {
        if #available(iOS 13, *) { return .systemGray5 }
        return UIColor(white: 0.1, alpha: 0.85)
    }()

    @objc(mo_whiteColor)    static let mo_white: UIColor = { return .white }()
    @objc(mo_redColor)      static let mo_red: UIColor = { return .systemRed }()
    @objc(mo_greenColor)    static let mo_green: UIColor = { return .systemGreen }()
    @objc(mo_blueColor)     static let mo_blue: UIColor = { return .systemBlue }()
    @objc(mo_orangeColor)   static let mo_orange: UIColor = { return .systemOrange }()

}
