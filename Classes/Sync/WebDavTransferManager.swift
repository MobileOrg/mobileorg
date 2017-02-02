//
//  WebDavTransferManager.swift
//  MobileOrg
//
//  Created by Mario Martelli on 01.02.17.
//  Copyright © 2017 Mario Martelli. All rights reserved.
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

@objc final class WebDavTransferManager: NSObject {

  var activeTransfer:TransferContext? = nil
  var transfers:[TransferContext] = []
  var active = false
  var paused = false
  var connection: URLSession?
  var data = NSMutableData()
  var fileSize:Int = 0
  var session:URLSession?

  static let instance = WebDavTransferManager()

  override init() {
    active = false
    paused = false
  }

  func enqueueTransfer(_ context: TransferContext) {
    transfers.append(context)
    ShowStatusView()
    dispatchNextTransfer()
  }

  func dispatchNextTransfer() {
    guard(!paused) else {return}
    guard transfers.count > 0 else {
      HideStatusView()
      return
    }

    if !active, let syncManager = SyncManager.instance() {
      activeTransfer = transfers.first
      activeTransfer?.success = true
      transfers.remove(at: 0)

      syncManager.transferFilename = activeTransfer?.remoteUrl.lastPathComponent
      syncManager.progressTotal = 0
      syncManager.updateStatus()

      active = true

      UIApplication.shared.isNetworkActivityIndicatorVisible = true

      processRequest(activeTransfer)

    }
  }

  func processRequest(_ cntxt: TransferContext?) {

    connection = nil
    if let context = cntxt {

      guard !context.dummy else {
        activeTransfer?.success = true
        // requestFinished(activeTransfer)
        return
      }


      var request = URLRequest(url: context.remoteUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
      if context.transferType == TransferTypeDownload {
        request.httpMethod = "GET"
      }
      else {
        request.httpMethod = "PUT"
        if let nsData = NSData(contentsOfFile: context.localFile) {
          request.httpBody = nsData as Data
        }
      }

      // FIXME: Check for invalid request

      data.length = 0
      //      let session = URLSession.shared

      session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)

      if let task = session?.dataTask(with: request) {
        task.resume()
      }
    }
  }

  func requestFinished(_ context: TransferContext) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
    if !context.success && context.abortOnFailure {
      transfers.removeAll()
    }

    if context.success {
      context.delegate.transferComplete!(context)
    } else {
      context.delegate.transferFailed!(context)
    }

    active = false
    self.activeTransfer = nil
    dispatchNextTransfer()
  }

  func pause() {
    paused = true
  }

  func resume() {
    paused = false
    dispatchNextTransfer()
  }

  func busy() -> Bool{
    return (transfers.count > 0 || active)
  }

  func queueSize() -> Int {
    return transfers.count
  }

  func abort() {
    if connection != nil {
      connection?.invalidateAndCancel()
    }
    transfers.removeAll()
    active = false
  }
}

extension WebDavTransferManager:URLSessionDataDelegate {

  func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    // We've got a URLAuthenticationChallenge - we simply trust the HTTPS server and we proceed
    if let trust = challenge.protectionSpace.serverTrust {
      completionHandler(.performDefaultHandling, nil)
    } else {
      let credential = URLCredential(user: Settings.instance().username!,
                                     password: Settings.instance().password!,
                                     persistence: URLCredential.Persistence.forSession)
      completionHandler(.useCredential, credential)
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    // The original request was redirected to somewhere else.
    // We create a new dataTask with the given redirection request and we start it.
    if let urlString = request.url?.absoluteString {
      print("willPerformHTTPRedirection to \(urlString)")
    } else {
      print("willPerformHTTPRedirection")
    }
    if let task = self.session?.dataTask(with: request) {
      task.resume()
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let err = error {
      print("Error: \(err.localizedDescription)")
      connection = nil
      activeTransfer?.errorText = "Failure"
      activeTransfer?.success = false
    } else {
      if activeTransfer?.transferType == TransferTypeDownload,
        activeTransfer?.success == true,
        activeTransfer?.dummy == false,
        let file = activeTransfer?.localFile {
        activeTransfer?.success = data.write(toFile: file, atomically: true)
      }
    }
    requestFinished(activeTransfer!)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

    if let httpResponse = response as? HTTPURLResponse {
      activeTransfer?.statusCode = UInt32(httpResponse.statusCode)

      if httpResponse.statusCode >= 400 && httpResponse.statusCode < 600 {
        activeTransfer?.success = false
      } else if httpResponse.statusCode == 302 {

        activeTransfer?.success = false
      }
    }

    data.length = 0
    self.fileSize = Int(response.expectedContentLength)
    print("didReceive response")
    completionHandler(URLSession.ResponseDisposition.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive responseData: Data) {
    // We've got the response body
    print("didReceive data")

    data.append(responseData)

    let mgr = SyncManager.instance()
    mgr?.progressTotal = Int32(fileSize)
    mgr?.progressCurrent = Int32(responseData.count)
    mgr?.updateStatus()
    // self.session?.finishTasksAndInvalidate()
  }
}
