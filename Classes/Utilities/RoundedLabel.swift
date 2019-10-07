//
//  RoundedLabel.swift
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

@objc
final class RoundedLabel: UILabel {

    private let textInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
    private let cornerRadius: CGFloat = 6

    @objc
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.font = .boldSystemFont(ofSize: 10)
        self.textColor = .mo_white
        self.backgroundColor = .mo_red
        self.clipsToBounds = true
        self.layer.cornerRadius = self.cornerRadius
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var text: String? {
        didSet { self.sizeToFit() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: self.textInsets))
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let size = super.sizeThatFits(size)
        return CGSize(width: size.width + (self.textInsets.left + self.textInsets.right), height: self.frame.height)
    }

}
