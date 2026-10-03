public struct CustomLoadEvaluator: CustomLoadEvaluating {
    public init() {}
    public func evaluate(_ provider: any CustomLoadProvider, state: CustomLoadState, coordinate: Double,
                         rate: Double, policy: CustomLoadPolicy, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        let identity = provider.identity, kind = provider.coordinateKind, ownerBudget = work.budget
        guard identity >= 0, policy.admits(coordinate: coordinate, rate: rate) else { throw .outsideDomain }
        let h = policy.coordinateProbe, k = policy.rateProbe
        guard coordinate + h != coordinate, coordinate - h != coordinate, rate + k != rate, rate - k != rate,
              policy.admits(coordinate: coordinate + h, rate: rate), policy.admits(coordinate: coordinate - h, rate: rate),
              policy.admits(coordinate: coordinate, rate: rate + k), policy.admits(coordinate: coordinate, rate: rate - k) else { throw .outsideDomain }
        let center = try sample(provider, state: state, q: coordinate, v: rate, identity: identity, kind: kind, ownerBudget: ownerBudget, work: &work)
        let plusQ = try sample(provider, state: state, q: coordinate + h, v: rate, identity: identity, kind: kind, ownerBudget: ownerBudget, work: &work)
        let minusQ = try sample(provider, state: state, q: coordinate - h, v: rate, identity: identity, kind: kind, ownerBudget: ownerBudget, work: &work)
        let plusV = try sample(provider, state: state, q: coordinate, v: rate + k, identity: identity, kind: kind, ownerBudget: ownerBudget, work: &work)
        let minusV = try sample(provider, state: state, q: coordinate, v: rate - k, identity: identity, kind: kind, ownerBudget: ownerBudget, work: &work)
        let dq = try loadFinite((plusQ.total() - minusQ.total()) / (2 * h))
        let dv = try loadFinite((plusV.total() - minusV.total()) / (2 * k))
        guard try policy.agrees(dq, center.coordinateDerivative), try policy.agrees(dv, center.rateDerivative) else { throw .derivativeMismatch }
        let dissipated = try loadFinite(-center.dissipative * rate)
        guard dissipated >= -policy.absoluteTolerance, try policy.agrees(dissipated, center.dissipatedPower) else { throw .invalidPassiveLaw }
        if policy.requireConservativeEnergy || center.conservative != 0 || plusQ.conservative != 0 || minusQ.conservative != 0 || plusV.conservative != 0 || minusV.conservative != 0 {
            guard let ePlus = plusQ.potentialEnergy, let eMinus = minusQ.potentialEnergy,
                  let energy = center.potentialEnergy, let energyPlusV = plusV.potentialEnergy,
                  let energyMinusV = minusV.potentialEnergy else { throw .missingEnergy }
            guard try policy.agrees(plusV.conservative, center.conservative), try policy.agrees(minusV.conservative, center.conservative),
                  try policy.agrees(energyPlusV, energy), try policy.agrees(energyMinusV, energy) else { throw .invalidPassiveLaw }
            let forceFromEnergy = try loadFinite(-(ePlus - eMinus) / (2 * h))
            guard try policy.agrees(forceFromEnergy, center.conservative) else { throw .derivativeMismatch }
        }
        guard !ownerBudget.isCancelled() else { throw .cancelled }
        try work.charge(0)
        return center
    }
    private func sample(_ provider: any CustomLoadProvider, state: CustomLoadState, q: Double, v: Double,
                        identity: Int, kind: ScalarCoordinateKind, ownerBudget: LoadBudget, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        guard provider.identity == identity, provider.coordinateKind == kind else { throw .providerChanged }
        guard !ownerBudget.isCancelled() else { throw .cancelled }
        try work.charge(1)
        let capturedBudget = ownerBudget, consumedBefore = work.consumed, peakBefore = work.peakScalars
        let response = try provider.response(coordinate: q, rate: v, state: state, work: &work)
        guard !capturedBudget.isCancelled() else { throw .cancelled }
        guard provider.identity == identity, provider.coordinateKind == kind,
              work.budget.maximumWork == capturedBudget.maximumWork,
              work.budget.maximumScalars == capturedBudget.maximumScalars,
              work.consumed >= consumedBefore, work.peakScalars >= peakBefore else { throw .providerChanged }
        _ = try response.total()
        try work.charge(0)
        return response
    }
}
