//
//  RepoRow.swift
//  App Dev To-Do
//
//  Repository list row component
//

import SwiftUI

struct RepoRow: View {
    let repository: Repository
    
    var body: some View {
        HStack(spacing: 12) {
            // Repo icon with TODO indicator
            ZStack {
                Circle()
                    .fill(repository.hasTodoFile == true ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: repository.hasTodoFile == true ? "checkmark.bubble.fill" : "shippingbox.fill")
                    .foregroundStyle(repository.hasTodoFile == true ? .green : .blue)
                    .font(.system(size: 20))
            }
            
            // Repo info
            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = repository.repoDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    Label(repository.owner, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if repository.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Pending todo count badge and last updated
            VStack(alignment: .trailing, spacing: 4) {
                // Show pending count badge if TODO.md exists
                if let count = repository.pendingTodoCount {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(count == 0 ? Color.green : Color.orange)
                        .clipShape(Circle())
                }
                
                Text(repository.lastUpdated, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RepoRow(repository: Repository(
        id: 1,
        name: "MyApp",
        owner: "scottcampbell",
        repoDescription: "A sample iOS application with awesome features",
        htmlUrl: "https://github.com/scottcampbell/MyApp",
        isPrivate: false,
        lastUpdated: Date(),
        hasTodoFile: true,
        pendingTodoCount: 3
    ))
}
