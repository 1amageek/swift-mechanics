public struct StandardLinearSolidState: Equatable, Sendable {
    public let law: StandardLinearSolidLaw
    public let strain: Double
    public let branchState: MaxwellState
    public var time: Double { branchState.time }
    public init(law: StandardLinearSolidLaw, time: Double, strain: Double, branchStress: Double) throws(MaterialError) {
        guard strain.isFinite, abs(strain) <= law.maximumStrain else { throw .invalidParameter(name: "standardLinearSolidState") }
        self.law=law; self.strain=strain
        branchState=try MaxwellState(law: law.branchLaw, time: time, stress: branchStress)
    }
}
