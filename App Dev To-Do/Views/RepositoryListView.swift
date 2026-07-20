//
//  RepositoryListView.swift
//  App Dev To-Do
//
//  Main view showing list of GitHub repositories
//

import SwiftUI
import SwiftData

struct RepositoryListView: View {
    @StateObject private var viewModel = RepositoryListVM()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            VStack {
                if !viewModel.hasToken {
                    NoTokenBanner()
                }
                
                List(viewModel.filteredRepositories) { repo in
                    NavigationLink(value: repo) {
                        RepoRow(repository: repo)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $viewModel.searchText, prompt: "Search repositories")
                .refreshable {
                    await viewModel.refreshRepositories()
                }
                .navigationTitle("My Repositories")
                .navigationDestination(for: Repository.self) { repo in
                    TodoView(repository: repo)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
                .alert("Error", isPresented: $viewModel.showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.errorMessage ?? "An error occurred")
                }
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
}

// MARK: - No Token Banner

struct NoTokenBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Add GitHub token in Settings to sync repositories")
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    RepositoryListView()
        .modelContainer(for: Repository.self, inMemory: true)
}
