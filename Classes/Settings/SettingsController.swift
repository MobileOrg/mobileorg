//
//  TestSettingsController.swift
//  MobileOrg
//
//  Created by Jamie Conlon on 04/01/2017.
//  Copyright © 2017 Sean Escriva. All rights reserved.
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
        
        if(Settings.instance().serverMode == ServerModeDropbox) {
            self.syncDetailLabel.text = "DropBox"
        } else {
            self.syncDetailLabel.text = "WebDAV"
        }
        
        let lastSync: Date! = Settings.instance().lastSync
        if lastSync != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "YYYY-MM-dd EEE HH:mm"
            self.lastSyncLabel.text = formatter.string(from: lastSync)
        } else {
            self.lastSyncLabel.text = "Not yet synced"
        }
        self.tableView.reloadData()
        self.tableView.setNeedsDisplay()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func onSyncComplete() {
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
    
    @IBAction func encryptionPasswordChanged(sender: AnyObject){
        self.encryptionTextField.resignFirstResponder()
        Settings.instance().encryptionPassword = encryptionTextField.text
    }
    
    func resetAppData() { // no idea if this works... Tests?
        // Session. Clear the saved state
        SessionManager.instance().reset()
        
        // Clear search
        AppInstance().searchController.reset()
        
        // Delete all nodes
        DeleteAllNodes()
        
        // Clear outline view
        AppInstance().rootOutlineController.reset()
        
        // Get rid of custom todo state, tags, etc
        Settings.instance().resetPrimaryTagsAndTodoStates()
        Settings.instance().resetAllTags()
        
        // Reset last sync time
        Settings.instance().lastSync = nil
    }
}
