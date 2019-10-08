//
//  ICloudOrgDocument.swift
//  MobileOrg
//
//  Created by Artem Loenko on 08/10/2019.
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

final class ICloudOrgDocument: UIDocument {
    var content: String? { get { return self._content } }
    private var _content: String?

    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            fatalError("Cannot cast retrieved content to Data type.")
        }
        self._content = String(data: data, encoding: .utf8)
    }

    override func contents(forType typeName: String) throws -> Any {
        guard let content = self._content else {
            fatalError("No content to save.")
        }
        return content.data(using: .utf8)
    }
}
