@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct ImplicitEulerResidual<Scalar: NumericalScalar>: NonlinearEquations {
    let equations: any ImplicitODEEquations
    let descriptor: ODEDescriptor
    let start: [Double]
    let scales: [Double]
    let time: Double
    let step: Double
    let control: RuntimeStepControl
    let capture: ImplicitAttemptCapture
    let workspace: ImplicitEquationWorkspacePool
    var identity: String { descriptor.identity }
    var coordinateCount: Int { start.count }

    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try check()
        guard point.count == coordinateCount, point.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
    }
    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try evaluate(point, output: &output, work: &work)
    }
    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        // Reevaluate the provider's physical derivative; no stored Newton residual is reused.
        try evaluate(point, output: &output, work: &work)
    }
    private func check() throws(NonlinearCause) {
        do throws(RuntimeFailure) { try control.beginWorkBlock(units: 1) }
        catch { capture.update { $0.cause = .runtime(error); $0.unavailable = $0.unavailable || error.failedSupplierWorkUnavailable }; throw .equation(.evaluationFailed(code: 1)) }
        guard equations.descriptor == descriptor, equations.implicitDomain == .smoothEuclidean else { throw .equationMetadataChanged }
    }
    private func evaluate(_ point: [Scalar], output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try check()
        guard point.count == coordinateCount, output.count == coordinateCount else { throw .invalidEvaluation }
        let count: Int
        do { count = try NumericalWork.product(8,coordinateCount); try work.chargeOperations(count) }
        catch { throw .numerical(error) }
        // Only Scalar == Double is instantiated by the public entry point. Reused conversion
        // buffers retain the supplier's scalar-generic Embedded witness specialization.
        var buffers = try workspace.take()
        defer { workspace.put(buffers) }
        for i in buffers.input.indices { buffers.input[i] = Double(point[i]); buffers.derivative[i] = .nan }
        let previous = work
        var failure: RuntimeFailure?
        do throws(RuntimeFailure) { try equations.derivative(time: time, point: buffers.input, into: &buffers.derivative, work: &work, control: control) }
        catch { failure = error }
        try ledger(previous, current: &work)
        if let failure { capture.update { $0.cause = .runtime(failure); $0.unavailable = $0.unavailable || failure.failedSupplierWorkUnavailable }; throw .equation(.evaluationFailed(code: 2)) }
        try check()
        guard buffers.derivative.count == coordinateCount, buffers.derivative.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        for i in output.indices {
            let value = (buffers.input[i]-start[i]-step*buffers.derivative[i])/scales[i]
            guard value.isFinite else { throw .numerical(.nonFiniteResult) }
            output[i] = Scalar(value)
        }
    }
    func jacobian(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try check()
        let entries: Int
        do { entries = try NumericalWork.product(coordinateCount,coordinateCount); try work.chargeOperations(try NumericalWork.product(5,entries)) }
        catch { throw .numerical(error) }
        guard point.count == coordinateCount, output.count == entries else { throw .invalidEvaluation }
        var buffers = try workspace.take()
        defer { workspace.put(buffers) }
        for i in buffers.input.indices { buffers.input[i] = Double(point[i]) }
        for i in buffers.tangent.indices { buffers.tangent[i] = .nan }
        let previous = work
        var failure: RuntimeFailure?
        do throws(RuntimeFailure) { try equations.derivativeJacobian(time: time, point: buffers.input, into: &buffers.tangent, work: &work, control: control) }
        catch { failure = error }
        try ledger(previous, current: &work)
        if let failure { capture.update { $0.cause = .runtime(failure); $0.unavailable = $0.unavailable || failure.failedSupplierWorkUnavailable }; throw .equation(.evaluationFailed(code: 3)) }
        try check()
        guard buffers.tangent.count == entries, buffers.tangent.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        for i in 0..<coordinateCount {
            for j in 0..<coordinateCount {
                let value = ((i == j ? 1.0 : 0.0)-step*buffers.tangent[i*coordinateCount+j])/scales[i]
                guard value.isFinite else { throw .numerical(.nonFiniteResult) }
                output[i*coordinateCount+j] = Scalar(value)
            }
        }
    }
    private func ledger(_ previous: NumericalWork, current: inout NumericalWork) throws(NonlinearCause) {
        guard ImplicitBudgetComposition.preservingLedger(previous,current) else {
            current = previous
            capture.update { $0.unavailable = true; $0.cause = .invalidOwnerAccess }
            throw .invalidEvaluation
        }
    }
}
