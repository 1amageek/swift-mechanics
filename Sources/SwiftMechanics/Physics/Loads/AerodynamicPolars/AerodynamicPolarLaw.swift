public struct AerodynamicPolarLaw: Sendable, Equatable {
    public let samples: [AerodynamicPolarSample]
    public let area: Double
    public let minimumPlanarSpeed: Double
    public let maximumPlanarSpeed: Double
    public let maximumSpanwiseFraction: Double
    public let maximumBasisDot: Double
    public init(samples: [AerodynamicPolarSample], area: Double, minimumPlanarSpeed: Double,
                maximumPlanarSpeed: Double, maximumSpanwiseFraction: Double, maximumBasisDot: Double,
                work: inout LoadWork) throws(LoadError) {
        try work.reserve(scalars: LoadWork.product(samples.count, 3))
        guard samples.count >= 2, area.isFinite, area > 0, minimumPlanarSpeed.isFinite, minimumPlanarSpeed > 0,
              maximumPlanarSpeed.isFinite, maximumPlanarSpeed >= minimumPlanarSpeed,
              maximumSpanwiseFraction.isFinite, maximumSpanwiseFraction >= 0, maximumSpanwiseFraction < 1,
              maximumBasisDot.isFinite, maximumBasisDot >= 0, maximumBasisDot < 1 else { throw .invalidInput }
        for i in samples.indices {
            try work.charge(1)
            if i > 0 { guard samples[i].angle > samples[i-1].angle else { throw .invalidInput } }
        }
        self.samples = samples; self.area = area; self.minimumPlanarSpeed = minimumPlanarSpeed
        self.maximumPlanarSpeed = maximumPlanarSpeed; self.maximumSpanwiseFraction = maximumSpanwiseFraction
        self.maximumBasisDot = maximumBasisDot
    }
}
