//
//  SettingsTest.swift
//  MobileOrg
//
//  Created by Mario Martelli on 07.01.17.
//  © 2017 Mario Martelli
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

import XCTest

class SettingsTest: XCTestCase {

  // test escaping of URLs
  func testUrlForFilename() {
    let ampersand = "Schnuddel & Huddel"
    let umlaut = "Überraschung an der Côte d'Azure"
    Settings.instance().serverMode = ServerModeDropbox
    XCTAssertEqual(Settings.instance().url(forFilename: ampersand), URL(string: "/Schnuddel%20&%20Huddel"))
    XCTAssertEqual(Settings.instance().url(forFilename: umlaut), URL(string: "/%C3%9Cberraschung%20an%20der%20C%C3%B4te%20d'Azure"))
  }

  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }

}
