//
//  TodoVM.swift
//  App Dev To-Do
//
//  ViewModel for to-do screen
//

import Foundation
import Combine
import UIKit
import SwiftData

@MainActor
class TodoVM: ObservableObject {
    @Published var repository: Repository?
    @Published var todoFile = TodoFile()
    @Published var newTodoText = ""
    @Published var selectedPriority: TodoItem.Priority? = nil
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var successMessage = ""
    @Published var useVoiceInput = false
    @Published var showPermissionDenied = false
    @Published var showPermissionRequest = false
    @Published var showCompletedTasks = false
    @Published var editingItemId: UUID?
    @Published var editText = ""
    
    @Published var syncingItemIds: Set<UUID> = []
    
    private let speechRecognizer = SpeechRecognizer()
    
    // Serial background sync queue so GitHub writes do not overlap
    private var syncTask: Task<Void, Never>?
    private var needsSync = false
    
    // Authoritative file SHA from the last successful write; avoids re-fetching after a write
    private var lastKnownFileSha: String?
    
    var visibleItems: [TodoItem] {
        if showCompletedTasks {
            return todoFile.items
        }
        // Keep completed items visible while they are still being synced.
        // They disappear only after the server has confirmed the change.
        return todoFile.items.filter { item in
            !item.isCompleted || isItemSyncing(item)
        }
    }
    
    var transcribedText: String {
        speechRecognizer.transcribedText
    }
    
    var isListening: Bool {
        speechRecognizer.isListening
    }
    
    /// Returns true when the given item has local changes that are still being synced
    func isItemSyncing(_ item: TodoItem) -> Bool {
        syncingItemIds.contains(item.id)
    }
    
    // MARK: - Setup
    
    func setRepository(_ repo: Repository) {
        let isSameRepo = repository?.id == repo.id
        self.repository = repo
        
        // If we're re-entering the same repo while changes are still syncing,
        // keep the local pending state so completed items stay visible.
        if isSameRepo && !syncingItemIds.isEmpty {
            return
        }
        
        loadTodoFile()
    }
    
    // MARK: - Data Loading
    
    func loadTodoFile() {
        guard let repo = repository else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let (content, sha) = try await GitHubService.shared.fetchTodoFile(
                    owner: repo.owner,
                    repo: repo.name
                )
                todoFile = TodoFile.fromMarkdown(content)
                lastKnownFileSha = sha
            } catch GitHubError.fileNotFound {
                // File doesn't exist yet, start with empty todo file
                todoFile = TodoFile()
                lastKnownFileSha = nil
            } catch let error as GitHubError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = "Failed to load to-do file: \(error.localizedDescription)"
                showError = true
            }
            
            // Keep the repository list counters in sync with what we just loaded
            updateRepoCounters()
            isLoading = false
        }
    }
    
    // MARK: - Voice Input
    
    func toggleVoiceInput() {
        // Check authorization state first
        let authState = SpeechRecognizer.getAuthorizationState()
        
        switch authState {
        case .authorized:
            // Already authorized, proceed with voice input
            useVoiceInput.toggle()
            if useVoiceInput {
                startListening()
            } else {
                stopVoiceInputAndCaptureText()
            }
            
        case .notDetermined:
            // Show permission request dialog
            showPermissionRequest = true
            
        case .denied:
            // Show permission denied dialog with Settings option
            showPermissionDenied = true
            
        case .unknown:
            errorMessage = "Unable to determine speech recognition permissions."
            showError = true
        }
    }
    
    /// Called when user confirms they want to grant permission
    func requestSpeechPermission() {
        showPermissionRequest = false
        
        Task {
            let granted = await SpeechRecognizer.requestAuthorization()
            if granted {
                // Permission granted, start voice input
                useVoiceInput = true
                startListening()
            } else {
                // Permission denied
                showPermissionDenied = true
            }
        }
    }
    
    /// Cancel permission request
    func cancelPermissionRequest() {
        showPermissionRequest = false
    }
    
    /// Open Settings app to allow user to enable permissions
    func openSettings() {
        showPermissionDenied = false
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Dismiss permission denied dialog
    func dismissPermissionDenied() {
        showPermissionDenied = false
    }
    
    private func startListening() {
        Task {
            do {
                try await speechRecognizer.startListening()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                useVoiceInput = false
            }
        }
    }
    
    private func stopVoiceInputAndCaptureText() {
        speechRecognizer.stopListening()
        // Move transcribed text to input field
        if !speechRecognizer.transcribedText.isEmpty {
            newTodoText = speechRecognizer.transcribedText
            speechRecognizer.clearTranscription()
        }
    }
    
    func stopVoiceInput() {
        speechRecognizer.stopListening()
        useVoiceInput = false
    }
    
    // MARK: - Toggle Completion
    
    func toggleTodoItem(_ item: TodoItem) {
        guard let index = todoFile.items.firstIndex(where: { $0.id == item.id }) else { return }
        
        todoFile.items[index].isCompleted.toggle()
        
        // Update the UI and counters immediately, then sync in the background.
        // Completed items stay visible until the sync is confirmed.
        updateRepoCounters()
        scheduleSync(for: Set([item.id]))
    }
    
    // MARK: - Edit Todo Item
    
    func startEditing(_ item: TodoItem) {
        editingItemId = item.id
        editText = item.text
    }
    
    func cancelEditing() {
        editingItemId = nil
        editText = ""
    }
    
    func saveEdit() {
        guard let editingId = editingItemId else { return }
        guard let index = todoFile.items.firstIndex(where: { $0.id == editingId }) else {
            cancelEditing()
            return
        }
        
        let trimmedText = editText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else {
            cancelEditing()
            return
        }
        
        todoFile.items[index].text = trimmedText
        editingItemId = nil
        editText = ""
        
        // Push the edit to GitHub in the background so the UI stays responsive
        scheduleSync(for: Set([editingId]))
    }
    
    // MARK: - Sync Queue
    
    /// Add the given item IDs to the sync queue and start a background sync if needed
    private func scheduleSync(for ids: Set<UUID> = []) {
        if !ids.isEmpty {
            syncingItemIds.formUnion(ids)
        }
        
        needsSync = true
        guard syncTask == nil else { return }
        
        syncTask = Task { [weak self] in
            await self?.runSyncLoop()
        }
    }
    
    /// Serial sync loop: keep syncing while new changes arrive
    private func runSyncLoop() async {
        isSaving = true
        defer {
            isSaving = false
            syncTask = nil
        }
        
        while needsSync {
            needsSync = false
            await performSync()
        }
    }
    
    /// Push the current local todoFile to GitHub, handling missing files and conflicts
    private func performSync() async {
        guard let repo = repository else { return }
        
        // Snapshot the IDs we are about to sync so items added mid-sync stay pending
        let idsToResolve = syncingItemIds
        
        do {
            // Use the authoritative SHA from the last successful write if available.
            // This avoids a read-after-write race where a fresh fetch returns a stale SHA.
            var sha = lastKnownFileSha
            if sha == nil {
                do {
                    let (_, fileSha) = try await GitHubService.shared.fetchTodoFile(
                        owner: repo.owner,
                        repo: repo.name
                    )
                    sha = fileSha
                } catch GitHubError.fileNotFound {
                    sha = nil
                }
            }
            
            // Save the full current local state
            let content = todoFile.toMarkdown()
            let newSha = try await GitHubService.shared.saveTodoFile(
                owner: repo.owner,
                repo: repo.name,
                content: content,
                sha: sha
            )
            
            // Cache the new SHA for the next sync
            lastKnownFileSha = newSha
            
            // Clear the pending sync state for the IDs that were synced
            syncingItemIds.subtract(idsToResolve)
            
            // Notify the user once the queue is empty
            if syncingItemIds.isEmpty {
                successMessage = "To-dos synced"
                showSuccess = true
            }
        } catch {
            errorMessage = "Failed to sync: \(error.localizedDescription)"
            showError = true
        }
    }
    
    /// Keep the repository counter badge in sync with the local todo list
    private func updateRepoCounters() {
        guard let repo = repository else { return }
        
        let pendingCount = todoFile.items.filter { !$0.isCompleted }.count
        repo.pendingTodoCount = pendingCount
        
        if repo.hasTodoFile != true {
            repo.hasTodoFile = !todoFile.items.isEmpty
        }
        
        try? repo.modelContext?.save()
    }
    
    // MARK: - Adding To-Dos
    
    func addTodo() {
        let textToUse = useVoiceInput ? speechRecognizer.transcribedText : newTodoText
        
        guard !textToUse.isEmpty else {
            errorMessage = "Please enter a to-do item"
            showError = true
            return
        }
        
        guard repository != nil else {
            errorMessage = "No repository selected"
            showError = true
            return
        }
        
        errorMessage = nil
        
        let newItem = TodoItem(
            text: textToUse,
            priority: selectedPriority
        )
        
        // Show the new to-do immediately and mark it as pending sync
        todoFile.items.append(newItem)
        updateRepoCounters()
        
        // Clear the input right away so the user can keep typing
        newTodoText = ""
        speechRecognizer.clearTranscription()
        selectedPriority = nil
        
        // Sync to GitHub in the background
        scheduleSync(for: Set([newItem.id]))
    }
    
    // MARK: - Validation
    
    var canAddTodo: Bool {
        let textToUse = useVoiceInput ? speechRecognizer.transcribedText : newTodoText
        return !textToUse.isEmpty
    }
}
