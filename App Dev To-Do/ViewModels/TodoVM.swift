//
//  TodoVM.swift
//  App Dev To-Do
//
//  ViewModel for to-do screen
//

import Foundation
import Combine

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
    
    private let speechRecognizer = SpeechRecognizer()
    
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
        useVoiceInput.toggle()
        
        if useVoiceInput {
            Task {
                do {
                    try await speechRecognizer.startListening()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                    useVoiceInput = false
                }
            }
        } else {
            speechRecognizer.stopListening()
            // Move transcribed text to input field
            if !speechRecognizer.transcribedText.isEmpty {
                newTodoText = speechRecognizer.transcribedText
                speechRecognizer.clearTranscription()
            }
        }
    }
    
    func stopVoiceInput() {
        speechRecognizer.stopListening()
        useVoiceInput = false
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
