public protocol GranularPreparing: Sendable {
    func prepare(revision: UInt64, frame: ModelReference, particles: [GranularParticle], boundaries: [GranularBoundary], laws: [ContactLawPair],
        motions: [GranularMotion], random: RuntimeRandomState, timeSeconds: Double, policy: GranularPolicy,
        numericalWork: inout NumericalWork, contactWork: inout ContactWork, supplierWork: inout GranularSupplierWork) throws(GranularError) -> GranularState
}
