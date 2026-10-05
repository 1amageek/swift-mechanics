public struct StandardLinearSolidLaw: Equatable, Sendable {
    public let equilibriumModulus: Double
    public let branchLaw: MaxwellLaw
    public let maximumStrain: Double
    public init(equilibriumModulus: Double, branchLaw: MaxwellLaw, maximumStrain: Double) throws(MaterialError) {
        guard equilibriumModulus.isFinite, equilibriumModulus > 0, maximumStrain.isFinite, maximumStrain > 0 else {
            throw .invalidParameter(name: "standardLinearSolidLaw")
        }
        self.equilibriumModulus=equilibriumModulus; self.branchLaw=branchLaw; self.maximumStrain=maximumStrain
    }
}
