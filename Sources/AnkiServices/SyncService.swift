import AnkiBackend
import AnkiProto
import AnkiSync
public import AnkiKit
public import Dependencies
import DependenciesMacros
import Foundation
import Logging
import SwiftProtobuf

private let logger = Logger(label: "com.ankiapp.sync.service")

@DependencyClient
public struct SyncService: Sendable {
    public var sync: @Sendable (_ endpoint: String, _ hostKey: String) async throws -> SyncSummary
    public var fullSync: @Sendable (_ endpoint: String, _ hostKey: String, _ direction: SyncDirection) async throws -> Void
    public var syncMedia: @Sendable (_ endpoint: String, _ hostKey: String) async throws -> Void
    public var login: @Sendable (_ endpoint: String, _ username: String, _ password: String) async throws -> String
}

extension SyncService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            sync: { endpoint, hostKey in
                var auth = Anki_Sync_SyncAuth()
                auth.hkey = hostKey
                auth.endpoint = endpoint

                var req = Anki_Sync_SyncCollectionRequest()
                req.auth = auth
                req.syncMedia = true

                do {
                    let responseBytes = try backend.call(
                        service: AnkiBackend.Service.sync,
                        method: AnkiBackend.SyncMethod.syncCollection,
                        request: req
                    )
                    let response = try Anki_Sync_SyncCollectionResponse(serializedBytes: responseBytes)
                    logger.info("SyncCollection: required=\(response.required), message='\(response.serverMessage)'")

                    if response.hasNewEndpoint, !response.newEndpoint.isEmpty {
                        auth.endpoint = response.newEndpoint
                    }

                    switch response.required {
                    case .noChanges:
                        return SyncSummary()

                    case .normalSync:
                        return SyncSummary()

                    case .fullSync, .fullDownload:
                        logger.info("Full download required")
                        var dlReq = Anki_Sync_FullUploadOrDownloadRequest()
                        dlReq.auth = auth
                        dlReq.upload = false
                        dlReq.serverUsn = response.serverMediaUsn
                        try backend.callVoid(
                            service: AnkiBackend.Service.sync,
                            method: AnkiBackend.SyncMethod.fullUploadOrDownload,
                            request: dlReq
                        )
                        try? backend.checkDatabase()
                        return SyncSummary(didFullDownload: true)

                    case .fullUpload:
                        // Deliberately NOT performed here. A full upload
                        // replaces the server's collection with this device's,
                        // and therefore overwrites every other device on the
                        // account — irreversibly, with no local undo. Doing
                        // that as a silent side effect of "sync" is the single
                        // most destructive thing this library could do.
                        //
                        // Report it and return having changed nothing; the
                        // client confirms with the user and calls
                        // `fullSync(direction: .upload)` if that is really what
                        // they want. (A full *download* stays automatic: it
                        // only costs this device, and is recoverable.)
                        logger.warning("Full upload required — not performed; caller must confirm")
                        return SyncSummary(requiresFullUpload: true)

                    case .UNRECOGNIZED(let v):
                        logger.warning("Unrecognized sync required: \(v)")
                        return SyncSummary()
                    }
                } catch let error as BackendError {
                    logger.error("Sync error: \(error.message)")
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            fullSync: { endpoint, hostKey, direction in
                var auth = Anki_Sync_SyncAuth()
                auth.hkey = hostKey
                auth.endpoint = endpoint

                var req = Anki_Sync_FullUploadOrDownloadRequest()
                req.auth = auth
                req.upload = (direction == .upload)

                do {
                    try backend.callVoid(
                        service: AnkiBackend.Service.sync,
                        method: AnkiBackend.SyncMethod.fullUploadOrDownload,
                        request: req
                    )
                } catch let error as BackendError {
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            syncMedia: { endpoint, hostKey in
                var auth = Anki_Sync_SyncAuth()
                auth.hkey = hostKey
                auth.endpoint = endpoint

                do {
                    try backend.callVoid(
                        service: AnkiBackend.Service.sync,
                        method: AnkiBackend.SyncMethod.syncMedia,
                        request: auth
                    )
                } catch let error as BackendError {
                    if error.isSyncAuthError { throw SyncError.authFailed }
                    throw SyncError(message: error.message)
                }
            },
            login: { endpoint, username, password in
                var req = Anki_Sync_SyncLoginRequest()
                req.username = username
                req.password = password
                req.endpoint = endpoint

                do {
                    let auth: Anki_Sync_SyncAuth = try backend.invoke(
                        service: AnkiBackend.Service.sync,
                        method: AnkiBackend.SyncMethod.syncLogin,
                        request: req
                    )
                    logger.info("Login successful for \(username)")
                    return auth.hkey
                } catch let error as BackendError {
                    logger.error("Login failed: \(error.message)")
                    throw SyncError.authFailed
                }
            }
        )
    }()
}

extension SyncService: TestDependencyKey {
    public static let testValue = SyncService()
}

extension DependencyValues {
    public var syncService: SyncService {
        get { self[SyncService.self] }
        set { self[SyncService.self] = newValue }
    }
}
