public struct DoubleActingHydraulicCylinder: Equatable, Sendable, HydraulicCylinderEvaluating {
    public let firstArea: Double
    public let secondArea: Double
    public let firstReferenceVolume: Double
    public let secondReferenceVolume: Double
    public let firstBulkModulus: Double
    public let secondBulkModulus: Double
    public let leakageConductance: Double
    public let maximumPressure: Double
    public let maximumFlow: Double
    public let maximumStroke: Double
    public let maximumRelativeVolumeChange: Double
    public let firstCompliance: Double
    public let secondCompliance: Double

    public init(firstArea: Double, secondArea: Double, firstReferenceVolume: Double, secondReferenceVolume: Double,
                firstBulkModulus: Double, secondBulkModulus: Double, leakageConductance: Double,
                maximumPressure: Double, maximumFlow: Double, maximumStroke: Double,
                maximumRelativeVolumeChange: Double) throws(ActuationError) {
        guard firstArea.isFinite, secondArea.isFinite, firstReferenceVolume.isFinite, secondReferenceVolume.isFinite,
              firstBulkModulus.isFinite, secondBulkModulus.isFinite, leakageConductance.isFinite,
              maximumPressure.isFinite, maximumFlow.isFinite, maximumStroke.isFinite, maximumRelativeVolumeChange.isFinite,
              firstArea > 0, secondArea > 0, firstReferenceVolume > 0, secondReferenceVolume > 0,
              firstBulkModulus > 0, secondBulkModulus > 0, leakageConductance >= 0,
              maximumPressure > 0, maximumFlow > 0, maximumStroke > 0,
              maximumRelativeVolumeChange > 0, maximumRelativeVolumeChange < 1 else { throw .invalidLaw }
        let c1 = firstReferenceVolume / firstBulkModulus, c2 = secondReferenceVolume / secondBulkModulus
        guard c1.isFinite, c2.isFinite, c1 > 0, c2 > 0 else { throw .invalidLaw }
        self.firstArea = firstArea; self.secondArea = secondArea
        self.firstReferenceVolume = firstReferenceVolume; self.secondReferenceVolume = secondReferenceVolume
        self.firstBulkModulus = firstBulkModulus; self.secondBulkModulus = secondBulkModulus
        self.leakageConductance = leakageConductance; self.maximumPressure = maximumPressure
        self.maximumFlow = maximumFlow; self.maximumStroke = maximumStroke
        self.maximumRelativeVolumeChange = maximumRelativeVolumeChange
        firstCompliance = c1; secondCompliance = c2
    }

    public func evaluate(stroke: Double, velocity: Double, firstPressure: Double, secondPressure: Double,
                         firstFlow: Double, secondFlow: Double, work: inout ActuationWork) throws(ActuationError) -> HydraulicCylinderResponse {
        try HydraulicArithmetic.preflight(&work, cylinder: true)
        guard stroke.isFinite, velocity.isFinite, firstPressure.isFinite, secondPressure.isFinite,
              firstFlow.isFinite, secondFlow.isFinite else { throw .invalidInput }
        guard abs(stroke) <= maximumStroke, firstPressure >= 0, secondPressure >= 0,
              firstPressure <= maximumPressure, secondPressure <= maximumPressure,
              abs(firstFlow) <= maximumFlow, abs(secondFlow) <= maximumFlow else { throw .outsideDomain }
        let firstChange = try HydraulicArithmetic.finite(firstArea * stroke / firstReferenceVolume)
        let secondChange = try HydraulicArithmetic.finite(secondArea * stroke / secondReferenceVolume)
        guard abs(firstChange) <= maximumRelativeVolumeChange, abs(secondChange) <= maximumRelativeVolumeChange else { throw .outsideDomain }
        let difference = try HydraulicArithmetic.finite(firstPressure - secondPressure)
        let leak = try HydraulicArithmetic.finite(leakageConductance * difference)
        let rate1 = try HydraulicArithmetic.finite((firstFlow - firstArea * velocity - leak) / firstCompliance)
        let rate2 = try HydraulicArithmetic.finite((secondFlow + secondArea * velocity + leak) / secondCompliance)
        let force = try HydraulicArithmetic.finite(firstArea * firstPressure - secondArea * secondPressure)
        let source = try HydraulicArithmetic.finite(firstPressure * firstFlow + secondPressure * secondFlow)
        let mechanical = try HydraulicArithmetic.finite(force * velocity)
        let energy = try HydraulicArithmetic.finite(0.5 * firstCompliance * firstPressure * firstPressure + 0.5 * secondCompliance * secondPressure * secondPressure)
        let storage = try HydraulicArithmetic.finite(firstCompliance * firstPressure * rate1 + secondCompliance * secondPressure * rate2)
        let loss = try HydraulicArithmetic.finite(leakageConductance * difference * difference)
        let residual = try HydraulicArithmetic.finite(source - mechanical - storage - loss)
        try work.charge(0)
        return HydraulicCylinderResponse(firstPressureRate: rate1, secondPressureRate: rate2, leakageFlow: leak,
            force: force, sourcePower: source, mechanicalPower: mechanical, storedEnergy: energy,
            storagePower: storage, dissipatedPower: loss, balanceResidual: residual)
    }
}
