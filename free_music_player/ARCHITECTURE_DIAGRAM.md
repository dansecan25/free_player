# Music Player Architecture - Before & After

## Current Architecture (Problematic)

```mermaid
graph TD
    A[Main App] --> B[PlaylistProvider]
    A --> C[AudioHandler]
    B --> D[AudioPlayer Instance 1]
    C --> E[AudioPlayer Instance 2]
    B --> F[UI State]
    C --> G[Notification Controls]
    
    H[Background] -.->|Kills Service| C
    I[User Returns] -.->|Fresh Start| A
    
    style D fill:#ff6b6b
    style E fill:#ff6b6b
    style H fill:#ff6b6b
```

**Problems:**
- Two separate AudioPlayer instances causing conflicts
- No audio session management
- Service gets killed in background
- State not persisted

## New Architecture (Fixed)

```mermaid
graph TD
    A[Main App] --> B[PlaylistProvider]
    A --> C[AudioHandler with Audio Session]
    C --> D[Single AudioPlayer Instance]
    B -.->|Uses| D
    C --> E[Notification Controls]
    C --> F[Bluetooth Controls]
    
    G[Audio Session Manager] --> C
    H[Wake Lock] --> C
    I[State Persistence] --> C
    
    J[Background] -.->|Service Continues| C
    K[User Returns] -.->|State Restored| A
    
    style D fill:#51cf66
    style G fill:#51cf66
    style H fill:#51cf66
    style I fill:#51cf66
```

**Improvements:**
- Single AudioPlayer instance managed by AudioHandler
- Proper audio session configuration
- Wake lock keeps service alive
- State persistence for seamless restoration

## Song Count Caching Flow

### Before (Inefficient)

```mermaid
sequenceDiagram
    participant User
    participant HomePage
    participant FutureBuilder
    participant FileSystem
    
    User->>HomePage: View Playlists
    HomePage->>FutureBuilder: Build
    FutureBuilder->>FileSystem: Count Songs
    FileSystem-->>FutureBuilder: Return Count
    FutureBuilder-->>HomePage: Display Count
    
    User->>HomePage: Navigate to Songs
    User->>HomePage: Go Back
    HomePage->>FutureBuilder: Rebuild
    FutureBuilder->>FileSystem: Count Songs AGAIN
    Note over FutureBuilder,FileSystem: Unnecessary I/O operation
    FileSystem-->>FutureBuilder: Return Count
    FutureBuilder-->>HomePage: Display "Counting..."
```

### After (Optimized)

```mermaid
sequenceDiagram
    participant User
    participant HomePage
    participant Playlist
    participant FileSystem
    
    User->>HomePage: View Playlists
    HomePage->>Playlist: Check songCount
    alt Count Cached
        Playlist-->>HomePage: Return Cached Count
        HomePage-->>User: Display Instantly
    else Count Not Cached
        Playlist->>FileSystem: Count Songs
        FileSystem-->>Playlist: Return Count
        Playlist->>Playlist: Cache Count
        Playlist-->>HomePage: Return Count
        HomePage-->>User: Display Count
    end
    
    User->>HomePage: Navigate to Songs
    User->>HomePage: Go Back
    HomePage->>Playlist: Check songCount
    Playlist-->>HomePage: Return Cached Count
    Note over HomePage,Playlist: No file system access needed
    HomePage-->>User: Display Instantly
```

## Background Playback State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading: User Selects Song
    Loading --> Playing: Audio Loaded
    Playing --> Paused: User Pauses
    Paused --> Playing: User Resumes
    Playing --> Completed: Song Ends
    Completed --> Playing: Next Song
    
    Playing --> Backgrounded: App Minimized
    Backgrounded --> Playing: App Restored
    
    note right of Backgrounded
        Audio Session Active
        Wake Lock Held
        Notification Visible
        State Persisted
    end note
    
    Backgrounded --> [*]: User Stops
    Playing --> [*]: User Stops
```

## Component Interaction Flow

```mermaid
graph LR
    A[User Action] --> B{Action Type}
    B -->|Play| C[PlaylistProvider]
    B -->|Pause| C
    B -->|Skip| C
    
    C --> D[AudioHandler]
    D --> E[Audio Session]
    D --> F[Just Audio Player]
    
    F --> G[System Audio]
    G --> H[Notification]
    G --> I[Bluetooth]
    G --> J[Lock Screen]
    
    K[State Manager] -.->|Save| D
    K -.->|Restore| D
    
    style E fill:#4dabf7
    style K fill:#4dabf7
```

## Key Improvements Summary

1. **Single Source of Truth**: One AudioPlayer instance in AudioHandler
2. **Proper Session Management**: Audio session configured for background playback
3. **State Persistence**: Playback state saved and restored
4. **Efficient Caching**: Song counts cached in memory
5. **Lifecycle Awareness**: Proper handling of app lifecycle events
6. **Resource Management**: Wake lock and audio focus properly managed