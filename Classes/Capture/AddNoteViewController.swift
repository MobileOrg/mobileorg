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

    private var toolsBar: UIToolbar = {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 45))
        bar.items = [
            UIBarButtonItem(title: "🔗", style: .plain, target: self, action: #selector(addLinkMarkup)),
            UIBarButtonItem(title: "📅", style: .plain, target: self, action: #selector(setDatePickerView)),
        ]
        bar.sizeToFit()
        return bar
    }()

    @objc func addLinkMarkup() {
        if let range = self.textView.selectedTextRange, !range.isEmpty {
            guard let selectedText = self.textView.text( in: range ) else { return }
            self.textView.replace( range, withText: "[[\(selectedText)][]]" )
            if let newCursor = self.textView.position(from: range.end, offset: 4) {
                self.textView.selectedTextRange = self.textView.textRange( from: newCursor, to: newCursor)
            }
        }
    }

    let datePicker = UIDatePicker()

    enum DateType: String {
        case schedule = "Schd"
        case deadline = "Dead"
        case agenda = "Agenda"
        case plain = "Plain"
    }

    private var datePickBar: UIToolbar = {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 45))
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(setDefaultInputView))
        let scheduleButton = UIBarButtonItem(title: DateType.schedule.rawValue, style: .plain, target: self, action: #selector(insertDate(_:)))
        let deadlineButton = UIBarButtonItem(title: DateType.deadline.rawValue, style: .plain, target: self, action: #selector(insertDate(_:)))
        let agendaButton = UIBarButtonItem(title: DateType.agenda.rawValue, style: .plain, target: self, action: #selector(insertDate(_:)))
        let plainButton = UIBarButtonItem(title: DateType.plain.rawValue, style: .plain, target: self, action: #selector(insertDate(_:)))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        bar.items = [ scheduleButton, deadlineButton, agendaButton, plainButton, spacer, cancelButton ]
        bar.sizeToFit()
        return bar
    }()

    private func datePicked() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd E hh:mm"
        return dateFormatter.string( from: self.datePicker.date )
    }

    private func replaceSelected( with newString: String ) {
        guard let range = self.textView.selectedTextRange else { return }
        self.textView.replace( range, withText: newString )
    }

    @objc private func insertDate(_ sender: UIBarButtonItem) {
        guard let title = sender.title else { return }
        let date = datePicked()
        switch DateType(rawValue: title) {
        case .agenda:
            replaceSelected( with: "<\(date)>" )
        case .deadline:
            replaceSelected( with: "DEADLINE: <\(date)>" )
        case .plain:
            replaceSelected( with: "[\(date)]" )
        case .schedule:
            replaceSelected( with: "SCHEDULED: <\(date)>" )
        case .none:
            break
        }
        self.setDefaultInputView()
    }

    func updateConstraintsWhenCustomKeyboardIsShown(customInputView: UIView) {
        guard let superview = customInputView.superview else { return }
        for constraint in superview.constraints {
            if (constraint.secondItem === customInputView && constraint.secondAttribute == .top) {
                constraint.priority = UILayoutPriority(999)
            }
        }
    }

    @objc func setDefaultInputView() {
        self.textView.inputAccessoryView = self.toolsBar
        self.textView.inputView = nil
        updateConstraintsWhenCustomKeyboardIsShown(customInputView: self.datePicker)
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
