# App Dev To-Do

An iOS app that connects to your GitHub account, lists your repositories, and lets you quickly add to-do items that get saved as `TODO.md` files directly in each repository.

## Features

- **GitHub Integration**: Lists all your repositories with pull-to-refresh
- **Voice Input**: Speak your to-do items instead of typing (optional)
- **Priority Tags**: Assign Low, Medium, or High priority to tasks
- **Offline Cache**: Repositories are cached locally using SwiftData
- **Secure Storage**: GitHub token stored securely in iOS Keychain
- **Markdown Output**: Creates/updates `TODO.md` files in your repos

## Screenshots

*Coming soon*

## Requirements

- iOS 17.0+
- Xcode 15.0+
- GitHub Personal Access Token

## Setup

1. Clone the repository
2. Open `App Dev To-Do.xcodeproj` in Xcode
3. Build and run on your device or simulator
4. On first launch, go to **Settings** and add your GitHub Personal Access Token

### Creating a GitHub Token

1. Go to [GitHub Settings > Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a name like "App Dev To-Do"
4. Select the `repo` scope for full repository access
5. Generate and copy the token
6. Paste into the app's Settings screen

## Architecture

```
App Dev To-Do/
├── Models/
│   ├── Repository.swift      # GitHub repo model (SwiftData)
│   ├── TodoItem.swift        # Task model with Markdown conversion
│   └── AppSettings.swift     # UserDefaults wrapper
├── Services/
│   ├── KeychainManager.swift # Secure token storage
│   ├── GitHubService.swift   # GitHub REST API client
│   └── SpeechRecognizer.swift # Voice-to-text using Speech framework
├── ViewModels/
│   ├── RepositoryListVM.swift
│   ├── TodoVM.swift
│   └── SettingsVM.swift
└── Views/
    ├── RepositoryListView.swift
    ├── TodoView.swift
    ├── SettingsView.swift
    └── Components/
        └── RepoRow.swift
```

## How It Works

1. **Authentication**: Your GitHub PAT is stored securely in the iOS Keychain
2. **Repository List**: Fetches your repos from GitHub API, caches them in SwiftData
3. **Add To-Do**: Type or speak a new task, optionally set priority
4. **Save to GitHub**: App reads existing `TODO.md`, appends your item, commits back to GitHub

## License

MIT License - feel free to use and modify as needed.
