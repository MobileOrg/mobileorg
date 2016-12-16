//
//  String+RegexSplitter.swift
//  MobileOrg
//
//  Created by Mario Martelli on 12.12.16.
//
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

public extension NSString {

  func componentsSeparatedBy(regex: String) -> Array<String> {

    do {
      var result:[String] = []
      let swiftString = String(self)
      let rgx = try NSRegularExpression(pattern: regex, options: [])

      let matches = rgx.matches(in: swiftString, options: [], range: NSRange(location: 0, length: swiftString.characters.count))
      for match in matches {
        for n in 0..<match.numberOfRanges {
          let range = match.rangeAt(n)
          let begin = swiftString.index(swiftString.startIndex, offsetBy: range.location)
          let end = swiftString.index(swiftString.startIndex, offsetBy: range.location+range.length)
          result.append(swiftString.substring(with: begin..<end))
        }
      }
      return result
    } catch {
      return []
    }
  }

  func arrayOfCaptureComponentsMatchedBy(regex: String) -> Array<Array<String>> {
    let capture = self.captureComponentsMatchedBy(regex: regex)
    if capture.count > 0 {
      let ret:[Array<String>] = [capture]
        return ret
    }
    return []
  }

  func captureComponentsMatchedBy(regex: String) -> Array<String> {

    do {
      var result:[String] = []
      let swiftString = String(self)
      let rgx = try NSRegularExpression(pattern: regex, options: [])

      let matches = rgx.matches(in: swiftString, options: [], range: NSRange(location: 0, length: swiftString.characters.count))
      for match in matches {
        for n in 0..<match.numberOfRanges {
          let range = match.rangeAt(n)
          let begin = swiftString.index(swiftString.startIndex, offsetBy: range.location)
          let end = swiftString.index(swiftString.startIndex, offsetBy: range.location+range.length)
          result.append(swiftString.substring(with: begin..<end))
        }
      }
      return result
    } catch {
      return []
    }
  }

  func rangeOf(regex: String) -> NSRange {
    let range = NSMakeRange(0, self.length)
    let match = self.range(of: regex, options: .regularExpression, range: range)
    return match
  }

  func isMatchedBy(regex: String) -> Bool {
    let range = NSMakeRange(0, self.length)
    let match = self.range(of: regex, options: .regularExpression, range: range)
    if match.location == NSNotFound {
      return false
    }
    return true
  }


  func stringByReplacingOccurrencesOf(regex: String, withString: String) -> String {

    let rgx = try! NSRegularExpression(pattern: regex,
                                         options: NSRegularExpression.Options.caseInsensitive)
    let range = NSMakeRange(0, self.length)
    let modString = rgx.stringByReplacingMatches(in: self as String,
                                                   options: [],
                                                   range: range,
                                                   withTemplate: withString)
    return modString
  }
}
