internal final class SleepImpactSystem:Sendable {
    let value:RigidDynamicsSystem
    let load:LoadWork
    init(_ value:RigidDynamicsSystem,load:LoadWork) { self.value=value;self.load=load }
}
