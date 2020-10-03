//
//  DropboxTransferManager.swift
//  MobileOrg
//
//  Created by Mario Martelli on 16.12.16.
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
import SwiftyDropbox

@objcMembers final class DropboxTransferManager: NSObject {

  var activeTransfer:TransferContext? = nil
  var transfers:[TransferContext] = []
  var _active = false
  var paused = false

  var active:Bool{
    get { return _active }
    set {_active = newValue }
  }
  
  func queueSize() -> Int {
    return transfers.count
  }

  func busy() -> Bool {
    return (transfers.count > 0 || active)
  }

  func abort() {
    transfers.removeAll()
  }

  // Workaround to suffice to TransferManager protocol


  static let instance = DropboxTransferManager()

  override init() {
    let filePath = Bundle.main.path(forResource: "AppKey", ofType: "plist")
    let plist = NSDictionary(contentsOfFile:filePath!)
    let dkist = plist?["Dropbox API Key"] as? NSDictionary
    let appKey = dkist?.object(forKey: "AppKey") as! String
    DropboxClientsManager.setupWithAppKey(appKey)
  }

  /// Login to Dropbox
  /// Login takes place over Dropbox App if installed
  /// otherwise over WebView. Authflow is handled afterwards asynchronely
  /// Further infos: http://dropbox.github.io/SwiftyDropbox/api-docs/latest/
  ///
  /// - Parameter rootController: viewController from where the call was made
  func login(_ rootController: UIViewController) {
    DropboxClientsManager.authorizeFromController(UIApplication.shared,
                                                  controller: rootController,
                                                  openURL: { (url: URL) -> Void in
                                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)})
  }


  /// Handle Dropbox Authorisation FLow
  /// Triggered by AppDelegate
  ///
  /// - Parameter url: URL used for Authorisation
  /// - Returns: always true 🙄
  func handleAuthFlow(url: URL) -> Bool {
    DropboxClientsManager.handleRedirectURL(url, completion: { authResult in
      switch authResult {
      case .success:
        NotificationCenter.default.post(name: Notification.Name(rawValue: "dropboxloginsuccess"), object: nil)

        print("Success! User is logged into Dropbox.")
      case .cancel:
        print("Authorization flow was manually cancelled by user!")
      case .error(_, let description):
        print("Error: \(description ?? "Unknown")")
      case .none:
        print("Unknown result.")
      }
    })
    return true
  }


  /// Indicates whether a Dropbox link is established or not
  ///
  /// - Returns: State of Dropbox link
  func isLinked() -> Bool {
    return DropboxClientsManager.authorizedClient != nil
  }

  /// Unlinks the user from Dropbox
  func unlink() {
    DropboxClientsManager.unlinkClients()
  }

  func enqueueTransfer(_ context: TransferContext){
    transfers.append(context)
    ShowStatusView()
    dispatchNextTransfer()
  }

  func dispatchNextTransfer() {

    if paused { return }
    
    if let syncManager = SyncManager.instance(),
      transfers.count > 0,
      transfers.first?.remoteUrl != nil,
      !active {

      activeTransfer = transfers.first

      activeTransfer?.success = true
      transfers.remove(at: 0)

      let filename = activeTransfer?.remoteUrl.lastPathComponent


      // Update status view text
      syncManager.transferFilename = filename
      syncManager.progressTotal = 0
      syncManager.updateStatus()

      active = true
      UIApplication.shared.isNetworkActivityIndicatorVisible = true
      processRequest( activeTransfer!)
    }

    // processRequest
  }

  func processRequest(_ context: TransferContext) {
    if !isLinked() {
      activeTransfer?.errorText = "Not logged in, please login from the Settings page.";
      activeTransfer?.success = false;
      requestFinished(activeTransfer!)
      return;
    }

    if context.dummy {
      activeTransfer?.success = true
      requestFinished(activeTransfer!)
      return
    }

    let remoteUrl = context.remoteUrl.absoluteString
    let path = remoteUrl.replacingOccurrences(of: "dropbox:///", with: "/")

    if context.transferType == TransferTypeDownload {
        downloadFile(from: path, to: context.localFile)
    } else {
      uploadFile(to: path, from: context.localFile)
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

  func downloadFile(from: String, to: String) {

    if let client = DropboxClientsManager.authorizedClient {

      let destURL = URL(string: "file://\((activeTransfer?.localFile)!)")
      let destination: (URL, HTTPURLResponse) -> URL = { temporaryURL, response in
        return destURL!
      }

      // Unescape URL
      if let unescapedFrom = from.removingPercentEncoding {

        // Download file from dropbox
        // files reside in app's root folder
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        client.files.download(path: unescapedFrom, overwrite: true, destination: destination)
          .response { response, error in
            if response != nil {
              self.activeTransfer?.success = true
              self.requestFinished(self.activeTransfer!)
            }
            if let error = error {
              switch error as CallError {
              case .routeError(let boxed, _, _, _):
                switch boxed.unboxed as Files.DownloadError {
                case .path(let lookupError):
                  switch lookupError {
                  case .notFound:
                    self.activeTransfer?.statusCode = 404
                    self.activeTransfer?.errorText = "The file \(String(describing: self.activeTransfer?.remoteUrl.lastPathComponent)) could not be found"
                  default:
                    self.activeTransfer?.errorText = error.description
                  }
                default:
                  self.activeTransfer?.errorText = error.description
                }
              default:
                self.activeTransfer?.errorText = error.description
              }
              self.activeTransfer?.success = false
              self.requestFinished(self.activeTransfer!)
            }
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
          }
          .progress { progressData in
            let mgr = SyncManager.instance()
            mgr?.progressTotal = 100
            mgr?.progressCurrent = Int32(progressData.fractionCompleted * 100.0)
            mgr?.updateStatus()
        }
      }
    }
  }

  func uploadFile(to: String, from: String) {
    if let client = DropboxClientsManager.authorizedClient,
      let data = NSData(contentsOfFile: from) {
      UIApplication.shared.isNetworkActivityIndicatorVisible = true

      // TODO: mute should be set by the user
      client.files.upload(path: to, mode: .overwrite, autorename: false, clientModified: nil, mute: false, input: Data(referencing: data))
        .response { response, error in
          if response != nil {
            self.activeTransfer?.success = true
            self.requestFinished(self.activeTransfer!)
          }
          if let error = error {
            self.activeTransfer?.errorText = error.description
            self.activeTransfer?.success = false
            self.requestFinished(self.activeTransfer!)
          }
          UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
        .progress { progressData in
          let mgr = SyncManager.instance()
          mgr?.progressTotal = 100
          mgr?.progressCurrent = Int32(progressData.fractionCompleted * 100.0)
          mgr?.updateStatus()
      }
    }
  }
}


