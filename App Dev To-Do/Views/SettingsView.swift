//
//  SettingsView.swift
//  App Dev To-Do
//
//  Settings screen for GitHub token configuration
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @StateObject private var viewModel = SettingsVM()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Token Status Section
                Section {
                    HStack {
                        Label {
                            Text("GitHub Token")
                        } icon: {
                            Image(systemName: viewModel.hasSavedToken ? "checkmark.shield.fill" : "exclamationmark.shield")
                                .foregroundStyle(viewModel.hasSavedToken ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        Text(viewModel.hasSavedToken ? "Configured" : "Not Set")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Token Input Section
                Section("Add Token") {
                    SecureField("Paste GitHub token here", text: $viewModel.tokenInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Button(action: { viewModel.saveToken() }) {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "key.fill")
                                Text("Save Token")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .listRowBackground(viewModel.tokenInput.isEmpty ? Color.gray : Color.blue)
                    .disabled(viewModel.tokenInput.isEmpty)
                    
                    Link(destination: viewModel.tokenCreationURL) {
                        Label("Create Token on GitHub", systemImage: "arrow.up.right.square")
                    }
                }
                
                // Instructions
                Section("Instructions") {
                    Text(viewModel.tokenInstructions)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Data Management
                Section("Data") {
                    if let lastSync = viewModel.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(role: .destructive, action: { viewModel.clearCache(modelContext: modelContext) }) {
                        Label("Clear Cache", systemImage: "trash")
                    }
                }
                
                // Remove Token
                if viewModel.hasSavedToken {
                    Section {
                        Button(role: .destructive, action: { viewModel.clearToken() }) {
                            Label("Remove Token", systemImage: "key.slash")
                        }
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Repository.self, inMemory: true)
}
