internal final class SleepImpactSource:Sendable {
    let physical:KinematicState
    let impulse:MechanismSleepImpulse
    let count:Int
    let reserved:Int
    init(physical:KinematicState,impulse:MechanismSleepImpulse,count:Int,reserved:Int) {
        self.physical=physical;self.impulse=impulse;self.count=count;self.reserved=reserved
    }
}
