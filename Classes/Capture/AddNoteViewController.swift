//
//  AddNoteViewController.swift
//  MobileOrg
//
//  Created by Artem Loenko on 18/10/2019.
//  Copyright © 2019 Artem Loenko.
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

final class AddNoteViewController: UIViewController {

    private var note: Note
    private lazy var textView: UITextView = {
        let view = UITextView()
        view.isScrollEnabled = true
        view.scrollsToTop = true
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.delegate = self
        view.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return view
    }()

    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var title: String? {
        get {
            if self.note.isFlagEntry() { return self.note.text?.isEmpty ?? true ? "New flagging note" : "Edit flagging note" }
            return self.note.text?.isEmpty ?? true ? "New note" : "Edit note"
        }
        set { }
    }

    required init(with note: Note) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var toolsBar: UIToolbar = {
        let bar = UIToolbar()
        let button1 = UIButton( type: .custom )
        button1.setImage( UIImage( named: "linkkey.png" ), for: .normal )
        button1.addTarget(self, action: #selector(addLinkMarkup), for: .touchUpInside)
        button1.frame = CGRect( x: 0, y: 0, width: 53, height: 51 )
        button1.bounds = CGRect( x: 0, y: 0, width: 53, height: 51 )
        let urlButton = UIBarButtonItem( customView: button1 )
        let button2 = UIButton( type: .custom )
        button2.setImage( UIImage( named: "datepick.png" ), for: .normal )
        button2.addTarget(self, action: #selector(setDatePickerView), for: .touchUpInside)
        button2.frame = CGRect( x: 0, y: 0, width: 53, height: 51 )
        button2.bounds = CGRect( x: 0, y: 0, width: 53, height: 51 )
        let dateButton = UIBarButtonItem( customView: button2 )
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        bar.items = [urlButton, dateButton, spacer ]
        bar.sizeToFit()
        return bar
    }()

    @objc func addLinkMarkup() {
        guard self.textView.text != nil else { return } // If no selected text, ignore.  Consider popup?
        if let range = self.textView.selectedTextRange, !range.isEmpty {
            let selectedText = self.textView.text( in: range )
            self.textView.replace( range, withText: "[[\(selectedText!)][]]" )
            let newCursor = self.textView.position(from: range.end, offset: 4)!
            self.textView.selectedTextRange = self.textView.textRange( from: newCursor, to: newCursor)
        }
    }

    let datePicker: UIDatePicker = {
        let picker = UIDatePicker(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 216))
        picker.datePickerMode = .dateAndTime
        return picker
    }()

    private lazy var datePickBar: UIToolbar = {
        let bar = UIToolbar()
        let cancelButton = UIBarButtonItem( title: "Cancel", style: .plain, target: self, action: #selector(setDefaultInputView) )
        let scheduleButton = UIBarButtonItem( title: "Schd", style: .plain, target: self, action: #selector(insertDateSchedule) )
        let deadlineButton = UIBarButtonItem( title: "Dead", style: .plain, target: self, action: #selector(insertDateDeadline) )
        let agendaButton = UIBarButtonItem( title: "Agenda", style: .plain, target: self, action: #selector(insertDateAgenda) )
        let plainButton = UIBarButtonItem( title: "Plain", style: .plain, target: self, action: #selector(insertDatePlain) )
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        bar.items = [ scheduleButton, deadlineButton, agendaButton, plainButton, spacer, cancelButton ]
        bar.sizeToFit()
        return bar
    }()

    private func datePicked() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd E hh:mm"
        //dateFormatter.formatOptions = [.withTime]
        return dateFormatter.string( from: self.datePicker.date )
    }

    private func replaceSelected( with newString: String ) {
        print( "replaceSelected" )
        if self.textView.text != nil {
            if let range = self.textView.selectedTextRange {
                self.textView.replace( range, withText: newString )
            }
        }
    }

    @objc func insertDateSchedule() {
        let date = datePicked()
        replaceSelected( with: "SCHEDULED: <\(date)>" )
        self.setDefaultInputView()
    }

    @objc func insertDateDeadline() {
        let date = datePicked()
        replaceSelected( with: "DEADLINE: <\(date)>" )
        self.setDefaultInputView()
    }

    @objc func insertDateAgenda() {
        let date = datePicked()
        replaceSelected( with: "<\(date)>" )
        self.setDefaultInputView()
    }

    @objc func insertDatePlain() {
        let date = datePicked()
        replaceSelected( with: "[\(date)]" )
        self.setDefaultInputView()
    }

    @objc func setDefaultInputView() {
        self.textView.inputView = nil
        self.textView.inputAccessoryView = self.toolsBar
        self.textView.reloadInputViews()
    }

    @objc func setDatePickerView() {
        self.textView.inputAccessoryView = self.datePickBar
        self.textView.inputView = self.datePicker
        self.textView.reloadInputViews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.textView.text = self.note.text
        self.view = self.textView
        if self.note.text?.isEmpty ?? true { self.textView.becomeFirstResponder() }
        self.navigationItem.rightBarButtonItem = self.addButton
        self.setDefaultInputView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.registerForKeyboardNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.unregisterForKeyboardNotifications()
    }

    // MARK: Actions

    private lazy var addButton = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(add))
    private lazy var doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneAction))

    private func adjustButtons(notification: Notification) {
        switch notification.name {
        case UIResponder.keyboardWillHideNotification:
            self.navigationItem.rightBarButtonItem = self.addButton
        case UIResponder.keyboardWillChangeFrameNotification:
            self.navigationItem.rightBarButtonItem = self.doneButton
        default: fatalError("Unexpected notification for the function: \(notification.name)")
        }
    }

    @objc private func doneAction() {
        self.save()
        self.textView.resignFirstResponder()
    }

    // MARK: Operations on notes

    private func save() {
        if !(self.note.text?.isEmpty ?? true) || self.note.text != self.textView.text {
            self.note.text = self.textView.text
            self.note.createdAt = Date()
            self.note.locallyModified = true
            Save()
        }
    }

    @objc private func add() {
        self.save()

        let newNote: Note = {
            guard let managedObjectContext = self.note.managedObjectContext, let note = NSEntityDescription.insertNewObject(forEntityName: String(describing: Note.self), into: managedObjectContext) as? Note else {
                fatalError("Cannot create a new note in the storage.")
            }
            note.createdAt = Date()
            note.noteId = UUID()
            note.locallyModified = true
            return note
        }()
        Save()

        AppInstance().noteListViewController.updateNoteCount()
        AppInstance().noteListViewController.edit(note: newNote)
    }

}

extension AddNoteViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        self.save()
    }
}

// MARK: Manage keyboard and the text view position
private extension AddNoteViewController {
    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handle(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handle(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    private func unregisterForKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func handle(notification: Notification) {
        self.adjustForKeyboard(notification: notification)
        self.adjustButtons(notification: notification)
    }

    private func adjustForKeyboard(notification: Notification) {
        guard let keyboardFrameEndUserValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let contentInset: UIEdgeInsets = {
            let keyboardViewEndFrame = view.convert(keyboardFrameEndUserValue.cgRectValue, from: self.view.window)
            switch notification.name {
            case UIResponder.keyboardWillHideNotification: return .zero
            case UIResponder.keyboardWillChangeFrameNotification:
                let bottom: CGFloat = keyboardViewEndFrame.height - view.safeAreaInsets.bottom
                return UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
            default: fatalError("Unexpected notification for the function: \(notification.name)")
            }
        }()

        self.textView.contentInset = contentInset
        self.textView.scrollIndicatorInsets = contentInset
    }
}
