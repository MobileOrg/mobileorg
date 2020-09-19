//
//  UIAlertController+MobileOrg.swift
//  MobileOrg
//
//  Created by Artem Loenko on 10/10/2019.
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

extension UIAlertController {

    @objc class func show(_ title: String, message: String) {
        self.show(title, message: message, confirmAction: nil, cancelAction: nil)
    }

    @objc class func show(_ title: String, message: String, confirmAction: ((UIAlertAction) -> Void)? = nil, cancelAction: ((UIAlertAction) -> Void)? = nil) {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: confirmAction)
        controller.addAction(ok)
        if cancelAction != nil {
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: cancelAction)
            controller.addAction(cancel)
        }
        guard let presentingViewController = self.mo_presentingViewController else {
            fatalError("Cannot find a proper presenting view controller.")
        }
        DispatchQueue.main.async {
            presentingViewController.present(controller, animated: true, completion: nil)
        }
    }

    private static var mo_presentingViewController: UIViewController? {
        let rootViewController = UIApplication.shared.delegate?.window??.rootViewController
        if let controller = (rootViewController as? UINavigationController)?.topViewController {
            return controller
        } else if let controller = (rootViewController as? UITabBarController)?.selectedViewController {
            return controller
        }
        return rootViewController
    }
    
}
