import MechanicsLoads
public struct LinearChamberLaw: Equatable, Sendable {
    public let binding:ActuatorBinding
    public let referenceVolume:Double,bulkModulus:Double,area:Double,leakage:Double,maximumPressure:Double,maximumFlow:Double,maximumStroke:Double,maximumRelativeVolumeChange:Double
    public init(binding:ActuatorBinding,referenceVolume:Double,bulkModulus:Double,area:Double,leakage:Double,maximumPressure:Double,maximumFlow:Double,
                maximumStroke:Double,maximumRelativeVolumeChange:Double) throws(ActuationError) {
        guard binding.stateKind == .fluid,binding.coordinate == .translation,
              referenceVolume.isFinite,bulkModulus.isFinite,area.isFinite,leakage.isFinite,maximumPressure.isFinite,maximumFlow.isFinite,maximumStroke.isFinite,maximumRelativeVolumeChange.isFinite,
              referenceVolume > 0,bulkModulus > 0,area > 0,leakage >= 0,maximumPressure > 0,maximumFlow > 0,maximumStroke > 0,
              maximumRelativeVolumeChange > 0,maximumRelativeVolumeChange < 1,
              binding.stateDomain.primaryLower == 0,binding.stateDomain.primaryUpper == maximumPressure,
              binding.stateDomain.secondaryLower == 0,binding.stateDomain.secondaryUpper == 0 else { throw .invalidLaw }
        let compliance=referenceVolume/bulkModulus
        guard compliance.isFinite,compliance > 0 else { throw .invalidLaw }
        self.binding=binding;self.referenceVolume=referenceVolume;self.bulkModulus=bulkModulus;self.area=area;self.leakage=leakage
        self.maximumPressure=maximumPressure;self.maximumFlow=maximumFlow;self.maximumStroke=maximumStroke;self.maximumRelativeVolumeChange=maximumRelativeVolumeChange
    }
    public var compliance:Double { referenceVolume/bulkModulus }
}
