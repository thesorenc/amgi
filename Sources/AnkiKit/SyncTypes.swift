public import Foundation

public enum SyncDirection: Sendable {
    case upload
    case download
}

public struct SyncError: Error, LocalizedError, Sendable, Equatable {
    public let message: String
    public let isRetryable: Bool

    public init(message: String, isRetryable: Bool = true) {
        self.message = message
        self.isRetryable = isRetryable
    }

    public var errorDescription: String? { message }

    public static let authFailed = SyncError(message: "Authentication failed", isRetryable: false)
    public static let networkUnavailable = SyncError(message: "Network unavailable", isRetryable: true)
    public static let fullSyncRequired = SyncError(message: "Full sync required", isRetryable: false)
    public static let conflictDetected = SyncError(message: "Conflict detected", isRetryable: false)
}

public struct SyncSummary: Sendable, Equatable {
    public var cardsPushed: Int
    public var cardsPulled: Int
    public var notesPushed: Int
    public var notesPulled: Int
    public var conflictsResolved: Int
    /// True when the sync replaced the local collection wholesale (a full
    /// download). Callers holding references into the old collection (open
    /// handles, queued operations keyed to old state) must invalidate them.
    public var didFullDownload: Bool
    /// The server asked for a **full upload**: this device's collection would
    /// replace the server's wholesale, and with it every other device on the
    /// account. `sync` deliberately does *not* perform it — it reports this and
    /// returns, having changed nothing. A client that wants it must confirm
    /// with the user and then call `fullSync(direction: .upload)` explicitly.
    ///
    /// The asymmetry with `didFullDownload` (which is performed automatically)
    /// is intentional. A full download costs this device its un-synced local
    /// state, which is bounded and recoverable. A full upload costs every
    /// *other* device its history, and nothing on this device can undo it.
    public var requiresFullUpload: Bool

    public init(
        cardsPushed: Int = 0, cardsPulled: Int = 0,
        notesPushed: Int = 0, notesPulled: Int = 0, conflictsResolved: Int = 0,
        didFullDownload: Bool = false, requiresFullUpload: Bool = false
    ) {
        self.cardsPushed = cardsPushed
        self.cardsPulled = cardsPulled
        self.notesPushed = notesPushed
        self.notesPulled = notesPulled
        self.conflictsResolved = conflictsResolved
        self.didFullDownload = didFullDownload
        self.requiresFullUpload = requiresFullUpload
    }
}

public struct MediaSyncSummary: Sendable, Equatable {
    public var filesUploaded: Int
    public var filesDownloaded: Int
    public var filesDeleted: Int

    public init(filesUploaded: Int = 0, filesDownloaded: Int = 0, filesDeleted: Int = 0) {
        self.filesUploaded = filesUploaded
        self.filesDownloaded = filesDownloaded
        self.filesDeleted = filesDeleted
    }
}
