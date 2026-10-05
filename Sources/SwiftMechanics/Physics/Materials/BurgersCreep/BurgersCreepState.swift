public struct BurgersCreepState: Equatable, Sendable {
    public let law: BurgersCreepLaw
    public let time: Double, appliedStress: Double, kelvinStrain: Double, viscousStrain: Double
    public init(law: BurgersCreepLaw, time: Double, appliedStress: Double, kelvinStrain: Double, viscousStrain: Double) throws(MaterialError) {
        guard time.isFinite, time >= 0, appliedStress.isFinite, abs(appliedStress) <= law.maximumStress,
              kelvinStrain.isFinite, abs(kelvinStrain) <= law.maximumKelvinStrain,
              viscousStrain.isFinite, abs(viscousStrain) <= law.maximumViscousStrain else {
            throw .invalidParameter(name: "burgersCreepState")
        }
        self.law=law; self.time=time; self.appliedStress=appliedStress
        self.kelvinStrain=kelvinStrain; self.viscousStrain=viscousStrain
    }
}
