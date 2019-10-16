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


  @objc func componentsSeparatedBy(regex: String) -> Array<String> {

    guard let re = try? NSRegularExpression(pattern: regex, options: [])
      else { return [] }

    let stop = "<SomeStringThatYouDoNotExpectToOccurInSelf>"
    let modifiedString = re.stringByReplacingMatches(
      in: self as String,
      options: [],
      range: NSRange(location: 0, length: self.length),
      withTemplate: stop) as NSString
    return modifiedString.components(separatedBy: stop)
  }


  @objc func arrayOfCaptureComponentsMatchedBy(regex: String) -> Array<Array<String>> {
    let capture = self.captureComponentsMatchedBy(regex: regex)
    if capture.count > 0 {
      let ret:[Array<String>] = [capture]
        return ret
    }
    return []
  }

  @objc func captureComponentsMatchedBy(regex: String) -> Array<String> {

    do {
      var result:[String] = []
      let swiftString = String(self)
      let rgx = try NSRegularExpression(pattern: regex, options: [])

      let matches = rgx.matches(in: swiftString, options: [], range: NSRange(swiftString.startIndex..., in: swiftString))
      for match in matches {
        for n in 0..<match.numberOfRanges {
            let range = match.range(at: n)
            guard range.lowerBound != NSNotFound else {
                //In the case of no match a range {NSNotFound, 0} is returned
                break;
            }

          let begin = swiftString.utf16.index(swiftString.startIndex, offsetBy: range.location)
          let end = swiftString.utf16.index(swiftString.startIndex, offsetBy: range.location+range.length)
          result.append(String(swiftString[begin..<end]))
        }
      }
      return result
    } catch {
      return []
    }
  }

  @objc func rangeOf(regex: String) -> NSRange {
    let range = NSMakeRange(0, self.length)
    let match = self.range(of: regex, options: .regularExpression, range: range)
    return match
  }

  @objc func isMatchedBy(regex: String) -> Bool {
    let range = NSMakeRange(0, self.length)
    let match = self.range(of: regex, options: .regularExpression, range: range)
    if match.location == NSNotFound {
      return false
    }
    return true
  }


  @objc func stringByReplacingOccurrencesOf(regex: String, withString: String) -> String {

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
