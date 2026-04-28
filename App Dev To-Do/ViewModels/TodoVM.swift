//
//  TodoVM.swift
//  App Dev To-Do
//
//  ViewModel for to-do screen
//

import Foundation
import Combine
import UIKit

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
    
    private let speechRecognizer = SpeechRecognizer()
    
    var visibleItems: [TodoItem] {
        if showCompletedTasks {
            return todoFile.items
        }
        return todoFile.items.filter { !$0.isCompleted }
    }
    
    var transcribedText: String {
        speechRecognizer.transcribedText
    }
    
    var isListening: Bool {
        speechRecognizer.isListening
    }
    
    // MARK: - Setup
    
    func setRepository(_ repo: Repository) {
        self.repository = repo
        loadTodoFile()
    }
    
    // MARK: - Data Loading
    
    func loadTodoFile() {
        guard let repo = repository else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let (content, _) = try await GitHubService.shared.fetchTodoFile(
                    owner: repo.owner,
                    repo: repo.name
                )
                todoFile = TodoFile.fromMarkdown(content)
            } catch GitHubError.fileNotFound {
                // File doesn't exist yet, start with empty todo file
                todoFile = TodoFile()
            } catch let error as GitHubError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = "Failed to load to-do file: \(error.localizedDescription)"
                showError = true
            }
            
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
        
        // Save the updated todo file
        saveTodoFile()
    }
    
    private func saveTodoFile() {
        guard let repo = repository else { return }
        
        Task {
            do {
                // Fetch current file SHA first (needed for update)
                let (_, sha) = try await GitHubService.shared.fetchTodoFile(
                    owner: repo.owner,
                    repo: repo.name
                )
                
                // Save updated content
                let content = todoFile.toMarkdown()
                try await GitHubService.shared.saveTodoFile(
                    owner: repo.owner,
                    repo: repo.name,
                    content: content,
                    sha: sha
                )
            } catch {
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Adding To-Dos
    
    func addTodo() {
        let textToUse = useVoiceInput ? speechRecognizer.transcribedText : newTodoText
        
        guard !textToUse.isEmpty else {
            errorMessage = "Please enter a to-do item"
            showError = true
            return
        }
        
        guard let repo = repository else {
            errorMessage = "No repository selected"
            showError = true
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let newItem = TodoItem(
                    text: textToUse,
                    priority: selectedPriority
                )
                
                try await GitHubService.shared.appendTodoItem(
                    owner: repo.owner,
                    repo: repo.name,
                    item: newItem
                )
                
                // Refresh local todo file
                loadTodoFile()
                
                // Clear input
                newTodoText = ""
                speechRecognizer.clearTranscription()
                selectedPriority = nil
                
                successMessage = "To-do added successfully!"
                showSuccess = true
                
            } catch let error as GitHubError {
                errorMessage = error.localizedDescription
                showError = true
            } catch {
                errorMessage = "Failed to save to-do: \(error.localizedDescription)"
                showError = true
            }
            
            isSaving = false
        }
    }
    
    // MARK: - Validation
    
    var canAddTodo: Bool {
        let textToUse = useVoiceInput ? speechRecognizer.transcribedText : newTodoText
        return !textToUse.isEmpty && !isSaving
    }
}
