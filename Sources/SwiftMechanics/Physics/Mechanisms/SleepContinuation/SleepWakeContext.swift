@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class SleepWakeContext:Sendable {
    let expected:RuntimeAcceptedState
    let history:MechanismSleepHistory
    let updated:MechanismSleepHistory
    let velocity:[Double]
    let target:[Double]
    let equation:AffineMechanismEquation
    let adapter:SleepMechanismEquation
    let ledger:SleepNumericalLedger
    let reserved:Int
    init(expected:RuntimeAcceptedState,history:MechanismSleepHistory,updated:MechanismSleepHistory,velocity:[Double],target:[Double],
         equation:AffineMechanismEquation,adapter:SleepMechanismEquation,ledger:SleepNumericalLedger,reserved:Int) {
        self.expected=expected;self.history=history;self.updated=updated;self.velocity=velocity;self.target=target
        self.equation=equation;self.adapter=adapter;self.ledger=ledger;self.reserved=reserved
    }
}
