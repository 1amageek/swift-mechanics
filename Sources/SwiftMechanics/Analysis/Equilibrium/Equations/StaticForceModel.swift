
public struct StaticForceModel: Equatable, Sendable {
    public let identity: String
    public let chart: StaticCoordinateChart
    public let law: StaticForceLaw
    public let minimumPosition: [Double]
    public let maximumPosition: [Double]
    public let parameterIdentity: String
    public let minimumParameter: Double
    public let maximumParameter: Double
    public let energyScale: Double
    public init(identity: String, chart: StaticCoordinateChart, law: StaticForceLaw, minimumPosition: [Double], maximumPosition: [Double], parameterIdentity: String,
                minimumParameter: Double, maximumParameter: Double, energyScale: Double, limits: EquilibriumLimits) throws(EquilibriumError) {
        let n=chart.count
        guard n<=limits.coordinates, minimumPosition.count==n, maximumPosition.count==n else { throw .capacityExceeded }
        try boundedIdentity(identity, limit: limits.identifierBytes); try boundedIdentity(parameterIdentity, limit: limits.identifierBytes)
        guard minimumParameter.isFinite, maximumParameter.isFinite, minimumParameter<=maximumParameter, energyScale.isFinite, energyScale>0 else { throw .invalidInput }
        for i in 0..<n { guard minimumPosition[i].isFinite, maximumPosition[i].isFinite, minimumPosition[i]<=maximumPosition[i],
            (chart.scales[i]/energyScale).isFinite, chart.scales[i]/energyScale>0 else { throw .invalidInput } }
        switch law {
        case .springs(let a, let b, let c, let l):
            guard a.count==n,b.count==n,c.count==n,l.count==n else { throw .invalidInput }
            for i in 0..<n { guard a[i].isFinite,b[i].isFinite,c[i].isFinite,l[i].isFinite else { throw .invalidInput } }
        case .pendulum(let g,let t):
            guard n==1, chart.dimensions[0] == .angle, g.isFinite,g>0,t.isFinite else { throw .invalidInput }
        }
        self.identity=identity; self.chart=chart; self.law=law; self.minimumPosition=minimumPosition; self.maximumPosition=maximumPosition
        self.parameterIdentity=parameterIdentity; self.minimumParameter=minimumParameter; self.maximumParameter=maximumParameter; self.energyScale=energyScale
    }
}
