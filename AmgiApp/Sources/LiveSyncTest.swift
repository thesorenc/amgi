// AmgiApp/Sources/LiveSyncTest.swift
//
// DEBUG/validation-only: drives a real AnkiWeb login + collection sync using
// credentials passed in the launch environment, so the rslib engine + sync path
// can be validated end-to-end without UI tap automation. Triggered only when
// AMGI_LIVE_SYNC_TEST=1 is present in the environment; otherwise a no-op.
//
// NOT part of the product — added during M0 foundation validation.
import AnkiBackend
import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Foundation

@MainActor
func maybeRunLiveSyncTest() async {
    let env = ProcessInfo.processInfo.environment
    guard env["AMGI_LIVE_SYNC_TEST"] == "1" else { return }

    let user = env["AMGI_SYNC_USER"] ?? ""
    let pass = env["AMGI_SYNC_PASS"] ?? ""
    let endpoint = env["AMGI_SYNC_ENDPOINT"] ?? "https://sync.ankiweb.net"
    NSLog("LIVESYNC: begin (userPrefix=%@, hasPass=%@, endpoint=%@)", String(user.prefix(3)), pass.isEmpty ? "no" : "yes", endpoint)

    @Dependency(\.syncService) var syncService
    @Dependency(\.deckClient) var deckClient
    @Dependency(\.ankiBackend) var backend

    do {
        let hkey = try await syncService.login(endpoint, user, pass)
        NSLog("LIVESYNC: login OK (hkeyLen=%d)", hkey.count)

        _ = try await syncService.sync(endpoint, hkey)
        NSLog("LIVESYNC: sync call returned")

        // After a full download the DB file is replaced; reopen to be safe.
        try? backend.reopenAfterFullSync()

        let decks = try deckClient.fetchAll()
        let totalDue = decks.reduce(0) { $0 + $1.counts.newCount + $1.counts.learnCount + $1.counts.reviewCount }
        NSLog("LIVESYNC: RESULT SUCCESS deckCount=%d totalDue=%d", decks.count, totalDue)
        for d in decks.prefix(25) {
            NSLog("LIVESYNC: deck name=%@ new=%d learn=%d review=%d",
                  d.name, d.counts.newCount, d.counts.learnCount, d.counts.reviewCount)
        }
    } catch {
        NSLog("LIVESYNC: RESULT FAILED error=%@", String(describing: error))
    }
}
