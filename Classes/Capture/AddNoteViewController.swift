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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.textView.text = self.note.text
        self.view = self.textView
        if self.note.text?.isEmpty ?? true { self.textView.becomeFirstResponder() }
        self.navigationItem.rightBarButtonItem = self.addButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.save()
        self.registerForKeyboardNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.unregisterForKeyboardNotifications()
    }

    // MARK: Actions

    private lazy var addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
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
                let bottom: CGFloat = {
                    if #available(iOS 11.0, *) { return keyboardViewEndFrame.height - view.safeAreaInsets.bottom }
                    else { return keyboardViewEndFrame.height }
                }()
                return UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
            default: fatalError("Unexpected notification for the function: \(notification.name)")
            }
        }()

        self.textView.contentInset = contentInset
        self.textView.scrollIndicatorInsets = contentInset
    }
}
