//
//  NoteListViewController.swift
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

@objc final class NoteListViewController: UITableViewController {

    var notes = [Note]()

    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(OutlineCell.self, forCellReuseIdentifier: OutlineCell.reuseIdentifier)
        self.navigationItem.rightBarButtonItem = self.addButton
        self.navigationItem.leftBarButtonItem = self.editButton

        NotificationCenter.default.addObserver(self, selector: #selector(onSyncComplete), name: self.syncCompleteNotificationName, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: self.syncCompleteNotificationName, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refresh()

        // TODO: Store in the session that there is no selected note
        // SettingsController.storeSelectedNote(_)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.stopEditing()
    }

    // MARK: Public API

    @objc func edit(note: Note) {
        let noteListIsOnTop = self.navigationController?.topViewController is NoteListViewController
        // If the note list is not on top then unwind to it
        if !noteListIsOnTop { self.navigationController?.popToRootViewController(animated: false) }
        let controller = AddNoteViewController(with: note)
        // Do not animate the push if we are replacing new note controller
        self.navigationController?.pushViewController(controller, animated: noteListIsOnTop)

        // TODO: Store that we are about to be editing this note..? maybe
        // Rethink this
        // SettingsController.storeSelectedNote(_)
    }

    @objc func addNote() {
        self.stopEditing()

        let newNote: Note = {
            guard let note = NSEntityDescription.insertNewObject(forEntityName: String(describing: Note.self), into: PersistenceStack.shared.moc) as? Note else {
                fatalError("Cannot create a new note in the storage.")
            }
            note.createdAt = Date()
            note.noteId = UUID()
            note.locallyModified = true
            return note
        }()
        Save()

        self.edit(note: newNote)
        self.updateNoteCount()
    }

    @objc func updateNoteCount() {
        self.updateBadge()
    }

    // MARK: Private functions & variables

    private let syncCompleteNotificationName = NSNotification.Name(rawValue: "SyncComplete")

    private lazy var addButton = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(addNote))
    private lazy var doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(edit(_:)))
    private lazy var editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(edit(_:)))

    @objc private func edit(_ sender: Any) {
        guard self.isEditing else {
            self.setEditing(true, animated: true)
            self.navigationItem.leftBarButtonItem = self.doneButton
            return
        }
        self.stopEditing()
    }

    private func stopEditing() {
        guard self.isEditing else { return }
        self.navigationItem.leftBarButtonItem = self.editButton
        self.setEditing(false, animated: true)
    }

    @objc private func onSyncComplete() {
        self.refresh()
    }

    private func refresh() {
        // INFO: do not extract the notes calculation, it has to be called only once within .refresh function
        self.notes = {
            let notes = AllActiveNotes() as? [Note] ?? []
            let emptyNotes = notes.filter { $0.text?.isEmpty ?? true }
            emptyNotes.forEach {
                $0.locallyModified = true
                $0.removed = true
                Save()
            }
            let notesWithoutEmpty = Array(Set(notes).subtracting(Set(emptyNotes)))
            let notesSortedByCreatedAt = notesWithoutEmpty.sorted {
                return Calendar.current.compare($0.createdAt ?? Date(), to: $1.createdAt ?? Date(), toGranularity: .second) == .orderedDescending
            }
            return notesSortedByCreatedAt
        }()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        self.updateEditButton()
        self.updateBadge()
    }

    private func updateBadge() {
        let noteCount = CountLocalNotes()
        self.navigationController?.tabBarItem.badgeValue = {
            guard noteCount > 0 else { return nil }
            return "\(noteCount)"
        }()
        UpdateAppBadge()
    }

    private func updateEditButton() {
        self.navigationItem.leftBarButtonItem?.isEnabled = CountLocalNotes() > 0
    }

    private func deleteNote(at index: Int) {
        guard self.notes.indices.contains(index) else {
            assertionFailure("Notes do not contain an object at \(index)")
            return
        }

        let noteToDelete = self.notes[index]
        noteToDelete.locallyModified = true
        noteToDelete.removed = true
        Save()

        self.notes.remove(at: index)
        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .left)

        if self.notes.isEmpty {
            self.stopEditing()
            self.navigationItem.leftBarButtonItem?.isEnabled = false
        }
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard self.notes.indices.contains(indexPath.row) else {
            fatalError("\(indexPath.row) is out of bounds")
        }
        let note = self.notes[indexPath.row]
        let title: String = {
            guard note.isFlagEntry() else { return note.heading() }
            guard let node = ResolveNode(note.nodeId) else {
                fatalError("Cannot resolve note with id: \(String(describing: note.noteId))")
            }
            return node.headingForDisplay()
        }()

        guard let cell = tableView.dequeueReusableCell(withIdentifier: OutlineCell.reuseIdentifier) as? OutlineCell else {
            fatalError("Cannot dequeue the cell for \(OutlineCell.reuseIdentifier)")
        }
        cell.update(title: title, createdAt: note.createdAt)
        cell.imageView?.image = {
            let resourceName = note.isFlagEntry() ? "flagged" : "note_entry"
            guard let path = Bundle.main.path(forResource: resourceName, ofType: "png") else {
                fatalError("Cannot resolve path for the resource: \(resourceName)")
            }
            return UIImage(named: path)
        }()

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            self.deleteNote(at: indexPath.row)
            self.refresh()
        default: break
        }
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard self.notes.indices.contains(indexPath.row) else {
            fatalError("\(indexPath.row) is out of bounds")
        }
        let note = self.notes[indexPath.row]
        self.edit(note: note)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

}
