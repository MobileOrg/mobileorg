//
//  TestSettingsController.swift
//  MobileOrg
//
//  Created by Jamie Conlon on 04/01/2017.
//  Copyright © 2017 Sean Escriva. All rights reserved.
//

import Foundation
import UIKit

class SyncSettingsController: UITableViewController {
    
    var pendingNewIndexUrl: String!
    var urlTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.tableView.setNeedsDisplay()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2;
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: // server mode
            return 2
        case 1:// server settings
            if (Settings.instance().serverMode == ServerModeDropbox) {
                return 2
            } else {
                return 3
            }
        default:
            break
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String {
        return ""
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 { // server settings section
            return "For help on configuration, visit http://mobileorg.ncogni.to ?????"
        } else {
            return ""
        }
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 { // first section
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "ServiceCell", for: indexPath) as UITableViewCell
            
            if indexPath.row == 0 { // first row - dropbox
                cell.textLabel?.text = "Dropbox"
                if Settings.instance().serverMode == ServerModeDropbox {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            } else { // second row - webdav
                cell.textLabel?.text = "WebDAV"
                if Settings.instance().serverMode == ServerModeWebDav {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            }
            return cell
            
        } else { // second section
            
            if (Settings.instance().serverMode == ServerModeWebDav) { // webdav is selected
                
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextInputCell

                    cell.textField.removeTarget(self, action: nil, for: .allEvents)
                    cell.textField.addTarget(self, action: #selector(serverUrlChanged), for: UIControlEvents.editingDidEnd)
                    cell.textFieldLabel.text = "URL"
                    cell.textField.placeholder = "Enter URL"
                    cell.textField.text = Settings.instance().indexUrl?.absoluteString
                    return cell
                } else if indexPath.row == 1 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextInputCell
                    
                    cell.textField.removeTarget(self, action: nil, for: .allEvents)
                    cell.textField.addTarget(self, action: #selector(usernameChanged), for: UIControlEvents.editingDidEnd)
                    cell.textFieldLabel.text = "Username"
                    cell.textField.placeholder = "Enter Username"
                    cell.textField.text = Settings.instance().username
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextInputCell
                    
                    cell.textField.removeTarget(self, action: nil, for: .allEvents)
                    cell.textField.addTarget(self, action: #selector(passwordChanged), for: UIControlEvents.editingDidEnd)
                    cell.textFieldLabel.text = "Password"
                    cell.textField.placeholder = "Enter Password"
                    cell.textField.isSecureTextEntry = true
                    cell.textField.text = Settings.instance().password
                    return cell
                }
            } else { // dropbox is selected
    
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath) as! TextInputCell
                    
                    cell.textField.removeTarget(self, action: nil, for: .allEvents)
                    cell.textField.addTarget(self, action: #selector(dropboxIndexChanged), for: UIControlEvents.editingDidEnd)
                    cell.textFieldLabel.text = "Index File"
                    cell.textField.text = Settings.instance().dropboxIndex
                    return cell
                    
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath)
                    
                    if (DropboxTransferManager.instance.isLinked()) {
                        cell.textLabel?.text = "Unlink from Dropbox"
                        cell.textLabel?.textColor = UIColor.red
                    } else {
                        cell.textLabel?.text = "Link to Dropbox"
                        cell.textLabel?.textColor = UIColor.green
                    }
                    return cell
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 { // server mode
            
            if indexPath.row == 0 { // dropbox
                Settings.instance().serverMode = ServerModeDropbox
            } else { // webdav
                Settings.instance().serverMode = ServerModeWebDav
            }
            self.tableView.reloadData()
            self.tableView.setNeedsDisplay()
            
        } else if (indexPath.section == 1 && Settings.instance().serverMode == ServerModeDropbox) { // server settings - dropbox mode
            
            if indexPath.row == 1 { // dropbox button
                
                if DropboxTransferManager.instance.isLinked() {
                    DropboxTransferManager.instance.unlink()
                } else {
                    DropboxTransferManager.instance.login(self)
                    // FIXME: State change is not reflected in UI
                }
                self.tableView.reloadData()
                self.tableView.setNeedsDisplay()
            }
        }
    }

    func serverUrlChanged(sender: UITextField) {
        print("server url changed")
        if sender.text?.rangeOf(regex: "http.*\\.(?:org|txt)$").location == NSNotFound {
            
            let alert = UIAlertController(title: "Invalid path",
                message: "This setting should be the complete URL to a .org file on a WebDAV server.  For instance, http://www.example.com/private/org/index.org",
                preferredStyle: .alert)
            let cancelAction = UIAlertAction( title: "Cancel", style: .cancel)
            
            alert.addAction(cancelAction)
            self.present(alert, animated: true)
    
            sender.text = ""
            sender.placeholder = "Enter valid URL"
        }
        
        if sender.text == Settings.instance().indexUrl.absoluteString {
            if (sender.text?.characters.count)! > 0 {
                // The user just changed URLs.  Let's see if they had any local changes.
                // We need to warn them that that the changes they have made will likely
                // not apply to the new data.
                if (CountLocalEditActions() > 0) {
                    let alert = UIAlertController(title: "Proceed with Change?", message:"Changing the URL to another set of files may invalidate the local changes you have made.  You may want to sync with the old URL first instead.\n\nProceed to change URL",
                        preferredStyle: .alert)
    
                    alert.addAction(UIAlertAction(title: "OK",
                                                  style: .default,
                                                  handler: {(alert: UIAlertAction!) in
                                                    self.applyNewServerUrl(url: self.pendingNewIndexUrl) }))

                    alert.addAction(UIAlertAction(title: "Cancel",
                                                  style: .cancel,
                                                  handler: {(alert: UIAlertAction!) in
                                                    sender.text! = Settings.instance().indexUrl.absoluteString
                                                    sender.text! = "" }))
                    self.present(alert, animated: true)
                    pendingNewIndexUrl = sender.text!
                    urlTextField = sender
                    return
                }
            }
            self.applyNewServerUrl(url: sender.text!)
        }
    }
    
    func applyNewServerUrl(url: String) {
    // Store the new URL
        Settings.instance().indexUrl = URL(string: url)
        self.resetAppData()
    }
    
    func usernameChanged(sender: UITextField) {
        Settings.instance().username = sender.text
    }
    
    func passwordChanged(sender: UITextField) {
        Settings.instance().password = sender.text
    }

    func dropboxIndexChanged(sender: UITextField) {
        Settings.instance().dropboxIndex = sender.text
        print("dropboxIndexChanged")
    }
    
    func resetAppData() {
        SessionManager.instance().reset()
        AppInstance().searchController.reset()
        DeleteAllNodes()
        AppInstance().rootOutlineController.reset()
        Settings.instance().resetPrimaryTagsAndTodoStates()
        Settings.instance().resetAllTags()
        Settings.instance().lastSync = nil
    }
}
