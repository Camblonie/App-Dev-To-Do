//
//  TodoView.swift
//  App Dev To-Do
//
//  View for adding and viewing to-do items for a repository
//

import SwiftUI

struct TodoView: View {
    @StateObject private var viewModel = TodoVM()
    let repository: Repository
    
    var body: some View {
        VStack(spacing: 0) {
            // Current TODO list
            todoListSection
            
            Divider()
            
            // Input section
            inputSection
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.setRepository(repository)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage)
        }
    }
    
    // MARK: - Todo List Section
    
    private var todoListSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if viewModel.todoFile.items.isEmpty {
                    EmptyTodoState()
                } else {
                    ForEach(viewModel.todoFile.items) { item in
                        TodoItemRow(item: item)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            // Text or Voice input
            if viewModel.useVoiceInput {
                VoiceInputView(viewModel: viewModel)
            } else {
                TextInputView(viewModel: viewModel)
            }
            
            // Priority selector
            PrioritySelector(selectedPriority: $viewModel.selectedPriority)
            
            // Add button
            Button(action: { viewModel.addTodo() }) {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                        Text("Add To-Do")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canAddTodo ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!viewModel.canAddTodo)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Text Input View

struct TextInputView: View {
    @ObservedObject var viewModel: TodoVM
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type your to-do...", text: $viewModel.newTodoText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            
            Button(action: { viewModel.toggleVoiceInput() }) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Voice Input View

struct VoiceInputView: View {
    @ObservedObject var viewModel: TodoVM
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(viewModel.transcribedText.isEmpty ? "Listening..." : viewModel.transcribedText)
                    .foregroundStyle(viewModel.transcribedText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: { viewModel.stopVoiceInput() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
            
            // Visual feedback while listening
            if viewModel.isListening {
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: 4, height: CGFloat.random(in: 10...30))
                            .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(Double(i) * 0.1), value: viewModel.isListening)
                    }
                }
                .frame(height: 40)
            }
        }
    }
}

// MARK: - Priority Selector

struct PrioritySelector: View {
    @Binding var selectedPriority: TodoItem.Priority?
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Priority:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ForEach(TodoItem.Priority.allCases, id: \.self) { priority in
                Button(action: { 
                    selectedPriority = selectedPriority == priority ? nil : priority
                }) {
                    Text(priority.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedPriority == priority ? priorityColor(priority) : Color.gray.opacity(0.2))
                        .foregroundStyle(selectedPriority == priority ? .white : .primary)
                        .cornerRadius(16)
                }
            }
            
            Spacer()
        }
    }
    
    private func priorityColor(_ priority: TodoItem.Priority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Todo Item Row

struct TodoItemRow: View {
    let item: TodoItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundStyle(item.isCompleted ? .green : .secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    if let priority = item.priority {
                        Text(priority.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(priorityColor(priority).opacity(0.2))
                            .foregroundStyle(priorityColor(priority))
                            .cornerRadius(4)
                    }
                    
                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func priorityColor(_ priority: TodoItem.Priority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Empty State

struct EmptyTodoState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No to-dos yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add your first task using the input below")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TodoView(repository: Repository(
            id: 1,
            name: "MyApp",
            owner: "scottcampbell",
            repoDescription: "A sample app",
            htmlUrl: "",
            isPrivate: false,
            lastUpdated: Date()
        ))
    }
}
