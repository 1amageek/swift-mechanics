
internal final class HardImpactRequest: Sendable {
    let input: HardImpactInput
    let policy: HybridPolicy
    let admission: DynamicsAdmission
    init(input: HardImpactInput, policy: HybridPolicy, admission: DynamicsAdmission) { self.input=input; self.policy=policy; self.admission=admission }
}
