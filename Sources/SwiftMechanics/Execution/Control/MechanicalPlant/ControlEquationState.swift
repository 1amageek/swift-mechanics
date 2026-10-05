internal struct ControlEquationState: Sendable {
    var busy=false
    var work:ActuationWork
    var response:ActuatorResponse?
    var history:ControlHistory?
    var endpoint:[Double]?
    var endpointDerivative:[Double]?
    var failure:ControlFailure?
    init(budget:ActuationBudget) { work=ActuationWork(budget:budget) }
}
