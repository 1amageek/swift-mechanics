@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class LoadedSleepWakeContext:Sendable {
    let source:RuntimeAcceptedState
    let original:LoadedMechanismSleepHistory
    let updated:LoadedMechanismSleepHistory
    let equation:StationaryAffineMechanismEquation
    let adapter:LoadedSleepMechanismEquation
    let ledger:SleepNumericalLedger
    let reserved:Int
    init(source:RuntimeAcceptedState,original:LoadedMechanismSleepHistory,updated:LoadedMechanismSleepHistory,equation:StationaryAffineMechanismEquation,adapter:LoadedSleepMechanismEquation,ledger:SleepNumericalLedger,reserved:Int) {
        self.source=source;self.original=original;self.updated=updated;self.equation=equation;self.adapter=adapter;self.ledger=ledger;self.reserved=reserved
    }
}
