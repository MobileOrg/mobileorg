//
//  OutlineCell.swift
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
//

import UIKit

@objc
final class OutlineCell: UITableViewCell {

    @objc static let reuseIdentifier: String = "OutlineCellIdentifier"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.textLabel?.numberOfLines = 0
        if #available(iOS 10.0, *) { self.textLabel?.adjustsFontForContentSizeCategory = true }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func update(title: String, note: String?, status: String?, done: Bool = false, priority: String?, tags: String?, scheduled: Date?, deadline: Date?) {
        self.textLabel?.attributedText = self.setup(title: title, note: note, status: status, done: done, priority: priority, tags: tags, scheduled: scheduled, deadline: deadline)
    }

    /// Format the data as an attributed string
    /// Format:
    /// [ Status ] [ Priority ] [ Tags ]
    /// Title
    /// [ Note ]
    /// [ Scheduled ]
    /// [ Deadline ]
    /// Base rules:
    /// - No more than 3 colours per cell;
    /// - No more than 2 font sizes per cell.
    private func setup(
        title: String,
        note: String?,
        status: String?,
        done: Bool = false,
        priority: String?,
        tags: String?,
        scheduled: Date?,
        deadline: Date?) -> NSAttributedString {
        let string = NSMutableAttributedString()

        if let status = status, !status.isEmpty {
            string.append(status.asStatus(done: done))
            string.space()
        }
        if let priority = priority, !priority.isEmpty {
            string.append(priority.asPriority(done: done))
            string.space()
        }
        if let tags = tags, !tags.isEmpty {
            let formattedTags = tags.split(separator: ":").joined(separator: " ")
            string.append(formattedTags.asTags(done: done))
        }

        if string.length > 0 { string.newLine() }
        string.append(title.asTitle(done: done))

        if let note = note, !note.isEmpty {
            string.newLine().append(note.asNote(done: done))
        }
        if let scheduled = scheduled {
            string.newLine().append("Scheduled:".asScheduled(with: scheduled, done: done))
        }
        if let deadline = deadline {
            string.newLine().append("Deadline:".description.asDeadline(with: deadline, done: done))
        }

        return string
    }
}
