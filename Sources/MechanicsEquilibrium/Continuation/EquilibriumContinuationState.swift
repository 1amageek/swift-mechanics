public struct EquilibriumContinuationState: Sendable {
    public let model: StaticForceModel
    public let constraints: StaticConstraints?
    public let branch: EquilibriumBranch
    public let position: [Double]
    public let parameter: Double
    public let time: Double
    public let accepted: EquilibriumSolution?
    /// Explicit caller seed is not labeled as a solved equilibrium.
    public init(model:StaticForceModel,constraints:StaticConstraints?,branch:EquilibriumBranch,position:[Double],parameter:Double,time:Double,limits:EquilibriumLimits)throws(EquilibriumError) {
        guard model.chart.count<=limits.coordinates,position.count==model.chart.count,branch.minimumPosition.count==position.count,
            parameter.isFinite,parameter>=model.minimumParameter,parameter<=model.maximumParameter,time.isFinite else { throw .invalidInput }
        try boundedIdentity(model.identity,limit:limits.identifierBytes)
        try boundedIdentity(branch.identity,limit:limits.identifierBytes)
        for i in position.indices { guard position[i].isFinite,position[i]>=branch.minimumPosition[i],position[i]<=branch.maximumPosition[i] else { throw .outsideDomain } }
        self.model=model;self.constraints=constraints;self.branch=branch;self.position=position;self.parameter=parameter;self.time=time;self.accepted=nil
    }
    internal init(solution:EquilibriumSolution) {
        model=solution.model;constraints=solution.constraints;branch=solution.branch;position=solution.position;parameter=solution.parameter;time=solution.time;accepted=solution
    }
}
