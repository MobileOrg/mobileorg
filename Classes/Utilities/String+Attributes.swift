//
//  String+Attributes.swift
//  MobileOrg
//
//  Created by Artem Loenko on 13/10/2019.
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

extension String {

    func asTitle(done: Bool = false) -> NSAttributedString {
        let attributes: [ NSAttributedString.Key: Any ] = [
            .font : UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: done ? UIColor.mo_tertiaryText : UIColor.mo_text
        ]
        return NSAttributedString(string: self, attributes: attributes)
    }

    func asNote(done: Bool = false) -> NSAttributedString {
        let attributes: [ NSAttributedString.Key: Any ] = [
            .font : UIFont.preferredFont(forTextStyle: .footnote),
            .foregroundColor: done ? UIColor.mo_tertiaryText : UIColor.mo_secondaryText
        ]
        return NSAttributedString(string: self, attributes: attributes)
    }

    func asStatus(done: Bool = false) -> NSAttributedString {
        let attributes: [ NSAttributedString.Key: Any ] = [
            .font : UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .semibold),
            .foregroundColor: done ? UIColor.mo_tertiaryText : UIColor.mo_accent
        ]
        return NSAttributedString(string: self, attributes: attributes)
    }

    func asPriority(done: Bool = false) -> NSAttributedString {
        let attributes: [ NSAttributedString.Key: Any ] = [
            .font : UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: done ? UIColor.mo_tertiaryText : UIColor.mo_secondaryText,
            .underlineStyle: NSUnderlineStyle.double.rawValue
        ]
        return NSAttributedString(string: self, attributes: attributes)
    }

    func asTags(done: Bool = false) -> NSAttributedString {
        let attributes: [ NSAttributedString.Key: Any ] = [
            .font : UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: done ? UIColor.mo_tertiaryText : UIColor.mo_secondaryText
        ]
        return NSAttributedString(string: self, attributes: attributes)
    }

    func asScheduled(with date: Date, done: Bool = false) -> NSAttributedString {
        let attributes: [ NSAttributedString.Key: Any ] = [
            .font : UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: done ? UIColor.mo_tertiaryText : UIColor.mo_secondaryText
        ]
        // FIXME: custom attributes for the date when overdue or coming soon
        // FIXME: replace nearby dates with human-readable versions (today, tomorrow, etc.)
        let _date = StoredPropertiesHolder._dateFormatter.string(from: date)
        return NSAttributedString(string: "\(self) \(_date)", attributes: attributes)
    }

    func asDeadline(with date: Date, done: Bool = false) -> NSAttributedString {
        return self.asScheduled(with: date, done: done)
    }

    func asCreatedAt(with date: Date) -> NSAttributedString {
        return self.asScheduled(with: date, done: false)
    }

    // MARK: Private

    private struct StoredPropertiesHolder {
        static var _dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none // FIXME: We need time for tasks with timestamps
            return formatter
        }()
    }

}

extension NSMutableAttributedString {
    @discardableResult
    func newLine() -> Self {
        self.append(NSAttributedString(string: "\n"))
        return self
    }

    @discardableResult
    func space() -> Self {
        self.append(NSAttributedString(string: " "))
        return self
    }

    @discardableResult
    func tab() -> Self {
        self.append(NSAttributedString(string: "\t"))
        return self
    }
}
