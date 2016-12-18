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

  func testCaptureComponentsMatchedBy() {
    let input = "   Emacs Naked\n   Scrollbar off and visible bell on\n    [[file:journal.org][Journal]]\n   #+begin_src emacs-lisp\n     (setq visible-bell t)\t\t       \n     (scroll-bar-mode 0)\n   #+end_src\n\n   Fullscreen on \n   Toolbar off\n   server start\n   #+begin_src emacs-lisp\n     (tool-bar-mode -1)\n     (toggle-frame-fullscreen)\n     (server-start)\n   #+end_src\n\n   \n   Unicode support\n   " as NSString
    let regex = "\\[\\[file:([a-zA-Z0-9/\\-_\\.]*\\.(?:org|txt))\\]\\[(.*)\\]\\]"

    let output:[String] = ["[[file:journal.org][Journal]]","journal.org", "Journal"]

    let test = input.captureComponentsMatchedBy(regex: regex)
    XCTAssertEqual(output, test)
  }

  func testCaptureComponentsMatchedByForFiles() {
    let input = "[[file:journal.org][journal.org]]" as NSString
    let regex = "\\[\\[file:([a-zA-Z0-9/\\-_\\.]*\\.(?:org|txt))\\]\\[(.*)\\]\\]"
    let output = ["[[file:journal.org][journal.org]]","journal.org", "journal.org"]
    let test = input.captureComponentsMatchedBy(regex: regex)
    XCTAssertEqual(output, test)
  }

  func testCaptureComponentsMatchedByForFiles2() {
    let input = "[[file:agendas.org][Agenda Views]]" as NSString
    let regex = "\\[\\[file:([a-zA-Z0-9/\\-_\\.]*\\.(?:org|txt))\\]\\[(.*)\\]\\]"
    let output:[String] = ["[[file:agendas.org][Agenda Views]]", "agendas.org", "Agenda Views"]
    let test = input.captureComponentsMatchedBy(regex: regex)
    XCTAssertEqual(output, test)
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
