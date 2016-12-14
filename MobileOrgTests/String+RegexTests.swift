//
//  String+RegexTests.swift
//  MobileOrg
//
//  Created by Mario Martelli on 14.12.16.
//
//

import XCTest
@testable import MobileOrg

class String_RegexTests: XCTestCase {


  func teststringByReplacingOccurrencesOfRegex() {

    // First test simple string
    let input = "Fira Code is an extension of the Fira Mono font containing a set of"
    let regex = "(?<!'|\")(https?://[a-zA-Z0-9\\-.]+(?::(\\d+))?(?:(?:/[a-zA-Z0-9\\-._?,'+\\&%$=~*!():@#\\\\]*)+)?)"

    let output = input.stringByReplacingOccurrencesOf(regex: regex,
                                                      withString: "<a href='$1'>$1</a>")
    // String should not be changed
    XCTAssertEqual(input, output)

    // Now test a link
    let realInput = "https://github.com/tonsky/FiraCode"
    let realoutput = "<a href='https://github.com/tonsky/FiraCode'>https://github.com/tonsky/FiraCode</a>"

    let linkOutput = realInput.stringByReplacingOccurrencesOf(regex: regex, withString: "<a href='$1'>$1</a>")

    // We should now have a href
    XCTAssertEqual(realoutput, linkOutput)

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
