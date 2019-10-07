//
//  SettingsController.swift
//  MobileOrg
//
//  Created by Jamie Conlon on 07.01.17.
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
import UIKit

class SettingsController: UITableViewController {
  
  @IBOutlet weak var appBadgeSwitch: UISwitch!
  @IBOutlet weak var autoCaptureSwitch: UISwitch!
  @IBOutlet weak var encryptionTextField: UITextField!
  @IBOutlet weak var versionLabel: UILabel!
  @IBOutlet weak var lastSyncLabel: UILabel!
  @IBOutlet weak var syncDetailLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if(Settings.instance().appBadgeMode == AppBadgeModeTotal) {
      appBadgeSwitch.setOn(true, animated: false)
    }
    if(Settings.instance().launchTab == LaunchTabCapture) {
      autoCaptureSwitch.setOn(true, animated: false)
    }
    
    self.versionLabel.text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onSyncComplete),
      name: NSNotification.Name(rawValue: "SyncComplete"),
      object: nil)
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    switch Settings.instance().serverMode {
    case ServerModeDropbox: self.syncDetailLabel.text = "DropBox"
    case ServerModeWebDav: self.syncDetailLabel.text = "WebDAV"
    case ServerModeICloud: self.syncDetailLabel.text = "iCloud"
    default: fatalError("Unexpected server mode: \(Settings.instance().serverMode)")
    }
    
    if let lastSync = Settings.instance().lastSync {
      let formatter = DateFormatter()
      formatter.dateFormat = "YYYY-MM-dd EEE HH:mm"
      self.lastSyncLabel.text = formatter.string(from: lastSync)
    } else {
      self.lastSyncLabel.text = "Not yet synced"
    }

    if let password = Settings.instance().encryptionPassword {
      self.encryptionTextField.text = password
    }

    self.tableView.reloadData()
    self.tableView.setNeedsDisplay()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @objc func onSyncComplete() {
    Settings.instance().lastSync = Date()
  }
  
  @IBAction func appBadgeToggle(sender: AnyObject) {
    if appBadgeSwitch.isOn {
      Settings.instance().appBadgeMode = AppBadgeModeTotal
    } else {
      Settings.instance().appBadgeMode = AppBadgeModeNone
    }
  }
  
  @IBAction func autoCaptureToggle(sender: AnyObject){
    if autoCaptureSwitch.isOn {
      Settings.instance().launchTab = LaunchTabCapture
    } else {
      Settings.instance().launchTab = LaunchTabOutline
    }
  }
  
  @IBAction func showCredits(_ sender: UIButton) {
    if let url = URL(string: "https://mobileorg.github.io/credits") {
      UIApplication.shared.openURL(url)
    }
  }

  @IBAction func showDocumentation(_ sender: UIButton) {
    if let url = URL(string: "https://mobileorg.github.io/documentation") {
      UIApplication.shared.openURL(url)
    }
  }

  @IBAction func showLicense(_ sender: Any) {
    if let url = URL(string: "https://mobileorg.github.io/license") {
      UIApplication.shared.openURL(url)
    }
  }

  @IBAction func encryptionPasswordChanged(sender: AnyObject){
    self.encryptionTextField.resignFirstResponder()
    Settings.instance().encryptionPassword = encryptionTextField.text
  }
}
