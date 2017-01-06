//
//  TextInputTableViewCell.swift
//  MobileOrg
//
//  Created by Jamie Conlon on 05/01/2017.
//  Copyright © 2017 Sean Escriva. All rights reserved.
//

import Foundation

public class TextInputCell: UITableViewCell {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var textFieldLabel: UILabel!
    
    @IBAction func textFieldChanged(sender: AnyObject) {
        self.textField.resignFirstResponder()
    }
}
	
