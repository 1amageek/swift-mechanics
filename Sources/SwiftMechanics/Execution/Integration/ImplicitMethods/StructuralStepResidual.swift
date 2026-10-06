@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct StructuralStepResidual<Scalar: NumericalScalar>: NonlinearEquations {
    let equations: any StructuralImplicitEquations
    let input: StructuralIntegrationState
    let scales: [StructuralResidualScale]
    let parameters: GeneralizedAlphaParameters
    let time: Double
    let step: Double
    let workspace: StructuralWorkspacePool
    let capture: StructuralAttemptCapture
    var identity: String { input.descriptor.identity }
    var coordinateCount: Int { input.displacement.count }

    func validateDomain(at point: [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try check()
        do { try work.chargeOperations(coordinateCount) } catch { throw .numerical(error) }
        guard point.count == coordinateCount, point.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
    }
    func residual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try evaluate(point, output: &output, original: false, work: &work)
    }
    func originalResidual(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try evaluate(point, output: &output, original: true, work: &work)
    }
    private func check() throws(NonlinearCause) {
        guard !Task.isCancelled else { throw .numerical(.cancelled) }
        guard equations.descriptor == input.descriptor, equations.implicitDomain == .smoothEuclidean,
              equations.massDomain == .constantMass, equations.residualDimensions.count == scales.count else { throw .equationMetadataChanged }
        for i in scales.indices { guard equations.residualDimensions[i] == scales[i].dimension else { throw .equationMetadataChanged } }
    }
    private func kinematics(_ point: [Scalar], into buffers: inout StructuralEvaluationWorkspace,
                            work: inout NumericalWork) throws(NonlinearCause) {
        guard point.count == coordinateCount else { throw .invalidEvaluation }
        do { try work.chargeOperations(try NumericalWork.product(40,coordinateCount)) }
        catch { throw .numerical(error) }
        let squaredStep = step*step, p = parameters
        for i in 0..<coordinateCount {
            let acceleration = Double(point[i])
            let displacement = input.displacement[i]+step*input.velocity[i]+squaredStep*((0.5-p.beta)*input.acceleration[i]+p.beta*acceleration)
            let velocity = input.velocity[i]+step*((1-p.gamma)*input.acceleration[i]+p.gamma*acceleration)
            if p.method == .generalizedAlpha {
                buffers.displacement[i] = (1-p.alphaF)*displacement+p.alphaF*input.displacement[i]
                buffers.velocity[i] = (1-p.alphaF)*velocity+p.alphaF*input.velocity[i]
                buffers.acceleration[i] = (1-p.alphaM)*acceleration+p.alphaM*input.acceleration[i]
            } else {
                buffers.displacement[i] = displacement; buffers.velocity[i] = velocity; buffers.acceleration[i] = acceleration
            }
            guard displacement.isFinite, velocity.isFinite, buffers.displacement[i].isFinite,
                  buffers.velocity[i].isFinite, buffers.acceleration[i].isFinite else { throw .numerical(.nonFiniteResult) }
            buffers.residual[i] = .nan; buffers.secondaryResidual[i] = .nan
        }
    }
    private func evaluate(_ point: [Scalar], output: inout [Scalar], original: Bool,
                          work: inout NumericalWork) throws(NonlinearCause) {
        try check()
        guard output.count == coordinateCount else { throw .invalidEvaluation }
        var buffers = try workspace.take()
        defer { workspace.put(buffers) }
        try kinematics(point, into: &buffers, work: &work)
        let evaluationTime = parameters.method == .generalizedAlpha ? time-parameters.alphaF*step : time
        try supplier(work: &work) { ledger throws(ImplicitMethodCause) in
            if original {
                try equations.originalResidual(time: evaluationTime, displacement: buffers.displacement, velocity: buffers.velocity,
                    acceleration: buffers.acceleration, into: &buffers.residual, work: &ledger)
            } else {
                try equations.residual(time: evaluationTime, displacement: buffers.displacement, velocity: buffers.velocity,
                    acceleration: buffers.acceleration, into: &buffers.residual, work: &ledger)
            }
        }
        guard buffers.residual.count == coordinateCount, buffers.residual.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        if parameters.method == .hht {
            // Constant mass allows the same a1 in both physical endpoint balances; their
            // weighted sum has exactly M*a1 and the HHT-weighted nonlinear force/load.
            try supplier(work: &work) { ledger throws(ImplicitMethodCause) in
                if original {
                    try equations.originalResidual(time: input.time, displacement: input.displacement, velocity: input.velocity,
                        acceleration: buffers.acceleration, into: &buffers.secondaryResidual, work: &ledger)
                } else {
                    try equations.residual(time: input.time, displacement: input.displacement, velocity: input.velocity,
                        acceleration: buffers.acceleration, into: &buffers.secondaryResidual, work: &ledger)
                }
            }
            guard buffers.secondaryResidual.count == coordinateCount, buffers.secondaryResidual.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        }
        do { try work.chargeOperations(try NumericalWork.product(8,coordinateCount)) }
        catch { throw .numerical(error) }
        for i in output.indices {
            let physical = parameters.method == .hht ?
                (1-parameters.alphaF)*buffers.residual[i]+parameters.alphaF*buffers.secondaryResidual[i] : buffers.residual[i]
            let value = physical/scales[i].referenceSI
            guard value.isFinite else { throw .numerical(.nonFiniteResult) }
            output[i] = Scalar(value)
        }
    }
    func jacobian(at point: [Scalar], into output: inout [Scalar], work: inout NumericalWork) throws(NonlinearCause) {
        try check()
        let entries: Int
        do { entries = try NumericalWork.product(coordinateCount,coordinateCount); try work.chargeOperations(try NumericalWork.product(8,entries)) }
        catch { throw .numerical(error) }
        guard output.count == entries else { throw .invalidEvaluation }
        var buffers = try workspace.take()
        defer { workspace.put(buffers) }
        try kinematics(point, into: &buffers, work: &work)
        for i in buffers.tangent.indices { buffers.tangent[i] = .nan; buffers.secondaryTangent[i] = .nan }
        let p = parameters
        let cq = (1-p.alphaF)*p.beta*step*step, cv = (1-p.alphaF)*p.gamma*step
        let ca = p.method == .generalizedAlpha ? 1-p.alphaM : 1-p.alphaF
        let evaluationTime = p.method == .generalizedAlpha ? time-p.alphaF*step : time
        try supplier(work: &work) { ledger throws(ImplicitMethodCause) in
            try equations.tangent(time: evaluationTime, displacement: buffers.displacement, velocity: buffers.velocity,
                acceleration: buffers.acceleration, displacementCoefficient: cq, velocityCoefficient: cv,
                accelerationCoefficient: ca, into: &buffers.tangent, work: &ledger)
        }
        guard buffers.tangent.count == entries, buffers.tangent.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        if p.method == .hht {
            try supplier(work: &work) { ledger throws(ImplicitMethodCause) in
                try equations.tangent(time: input.time, displacement: input.displacement, velocity: input.velocity,
                    acceleration: buffers.acceleration, displacementCoefficient: 0, velocityCoefficient: 0,
                    accelerationCoefficient: p.alphaF, into: &buffers.secondaryTangent, work: &ledger)
            }
            guard buffers.secondaryTangent.count == entries, buffers.secondaryTangent.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
        }
        for i in 0..<coordinateCount {
            for j in 0..<coordinateCount {
                let index = i*coordinateCount+j
                let value = (buffers.tangent[index]+(p.method == .hht ? buffers.secondaryTangent[index] : 0))/scales[i].referenceSI
                guard value.isFinite else { throw .numerical(.nonFiniteResult) }
                output[index] = Scalar(value)
            }
        }
    }
    private func supplier(work: inout NumericalWork,
        operation: (inout NumericalWork) throws(ImplicitMethodCause) -> Void) throws(NonlinearCause) {
        try check()
        let previous = work
        var failure: ImplicitMethodCause?
        do throws(ImplicitMethodCause) { try operation(&work) } catch { failure = error }
        guard ImplicitBudgetComposition.preservingLedger(previous,work) else {
            work = previous; capture.fail(.invalidOwnerAccess, unavailable: true); throw .invalidEvaluation
        }
        if let failure {
            let unavailable: Bool
            if case .runtime(let error) = failure { unavailable = error.failedSupplierWorkUnavailable }
            else if case .nonlinear(let error) = failure { unavailable = error.failedSupplierWorkUnavailable }
            else { unavailable = false }
            capture.fail(failure, unavailable: unavailable)
            if case .numerical(let error) = failure { throw .numerical(error) }
            throw .equation(.evaluationFailed(code: 4))
        }
        try check()
    }
}
