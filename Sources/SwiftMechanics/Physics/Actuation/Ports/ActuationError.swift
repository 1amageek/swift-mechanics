public enum ActuationError: Error, Equatable, Sendable {
    case invalidInput, invalidLaw, nonfiniteResult, outsideDomain, staleBinding, staleTime, incompatibleMode, incompatibleAuthority
    case unsupportedChart, frameMismatch, residualMismatch, capacityExceeded, workExhausted, sequenceOverflow, cancelled
    case core(CoreError), load(LoadError), numerical(NumericalError), runtime(RuntimeFailureCode)
}
internal func actuationFinite(_ value:Double) throws(ActuationError) -> Double {
    guard value.isFinite else { throw .nonfiniteResult };return value
}
internal func actuationClip(_ value:Double,_ limit:Double) -> Double { min(limit,max(-limit,value)) }
internal func actuationNumerics(_ operation:() throws(NumericalError) -> Void) throws(ActuationError) {
    do { try operation() } catch { throw .numerical(error) }
}

internal func actuationRuntimeFailure(_ error:ActuationError,id:String) -> RuntimeFailure {
    switch error {
    case .cancelled:return RuntimeFailure(.cancelled,contributor:id,message:"Actuator operation cancelled.")
    case .capacityExceeded,.workExhausted,.numerical:return RuntimeFailure(.contributorBudgetExceeded,contributor:id,message:"Actuator operation exhausted a declared ledger.")
    case .runtime(let code):return RuntimeFailure(code,contributor:id,message:"Actuator Runtime supplier failed.")
    default:return RuntimeFailure(.invalidContributor,contributor:id,message:"Actuator binding/time/state/law validation failed.")
    }
}
