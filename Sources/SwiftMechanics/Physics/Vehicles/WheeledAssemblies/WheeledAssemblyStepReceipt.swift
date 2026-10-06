public struct WheeledAssemblyStepReceipt: Sendable {
    public let state: WheeledAssemblyState
    public let start, end: WheeledAssemblyEvaluation
    public let estimatedRoadWork, estimatedMotorWork, estimatedSteeringWork: Double
    public let estimatedBrakeLoss, estimatedSuspensionLoss, energyResidual: Double
    public let originalSteeringSourceWork, steeringWorkQuadratureDifference: Double
    public let linearMomentumResidual, angularMomentumResidual: Vector3
    internal init(state: WheeledAssemblyState, start: WheeledAssemblyEvaluation, end: WheeledAssemblyEvaluation,
                  estimatedRoadWork: Double, estimatedMotorWork: Double, estimatedSteeringWork: Double,
                  estimatedBrakeLoss: Double, estimatedSuspensionLoss: Double, energyResidual: Double,
                  originalSteeringSourceWork: Double, steeringWorkQuadratureDifference: Double,
                  linearMomentumResidual: Vector3, angularMomentumResidual: Vector3) {
        self.state=state; self.start=start; self.end=end; self.estimatedRoadWork=estimatedRoadWork
        self.estimatedMotorWork=estimatedMotorWork; self.estimatedSteeringWork=estimatedSteeringWork
        self.estimatedBrakeLoss=estimatedBrakeLoss; self.estimatedSuspensionLoss=estimatedSuspensionLoss; self.energyResidual=energyResidual
        self.originalSteeringSourceWork=originalSteeringSourceWork; self.steeringWorkQuadratureDifference=steeringWorkQuadratureDifference
        self.linearMomentumResidual=linearMomentumResidual; self.angularMomentumResidual=angularMomentumResidual
    }
}
