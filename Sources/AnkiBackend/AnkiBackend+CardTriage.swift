import AnkiProto
import Foundation

/// Card-triage operations (suspend / bury / flag / restore) used by review
/// surfaces. amgi otherwise leaves the scheduler bury/suspend and cards flag
/// methods unwrapped; these thin public wrappers reach them through the
/// `package` invoke primitives, so a caller that already holds the backend can
/// use them directly without a DI service.
extension AnkiBackend {
    public enum BuryOrSuspendMode: Sendable {
        /// Hide until explicitly un-suspended.
        case suspend
        /// Hide until the next day (sibling/auto bury).
        case burySched
        /// Hide until the next day (manual user bury).
        case buryUser

        fileprivate var proto: Anki_Scheduler_BuryOrSuspendCardsRequest.Mode {
            switch self {
            case .suspend: .suspend
            case .burySched: .burySched
            case .buryUser: .buryUser
            }
        }
    }

    /// Suspend or bury the given cards.
    public func buryOrSuspend(cardIds: [Int64], mode: BuryOrSuspendMode) throws {
        var req = Anki_Scheduler_BuryOrSuspendCardsRequest()
        req.cardIds = cardIds
        req.mode = mode.proto
        try callVoid(service: Service.scheduler,
                     method: SchedulerMethod.buryOrSuspendCards,
                     request: req)
    }

    /// Set (or clear, with `flag == 0`) the colored flag on the given cards.
    /// Flags 1–7 map to Anki's flag colors.
    public func setFlag(cardIds: [Int64], flag: UInt32) throws {
        var req = Anki_Cards_SetFlagRequest()
        req.cardIds = cardIds
        req.flag = flag
        try callVoid(service: Service.cards,
                     method: CardsMethod.setFlag,
                     request: req)
    }
}
