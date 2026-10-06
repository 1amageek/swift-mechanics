public protocol WheeledAssemblyEvaluating: Sendable {
    func initialize(configuration: WheeledAssemblyConfiguration, state: CompiledKinematicState,
                    steering: ActuatorState, work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyState
    func query(state: WheeledAssemblyState, driver: WheeledAssemblyDriver, road: WheeledAssemblyRoadInput,
               work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyEvaluation
    func step(state: WheeledAssemblyState, driver: WheeledAssemblyDriver, road: WheeledAssemblyRoadInput,
              dt: Double, work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyStepReceipt
}
