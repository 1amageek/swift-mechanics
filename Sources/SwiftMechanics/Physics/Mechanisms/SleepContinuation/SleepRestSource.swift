internal final class SleepRestSource:Sendable {
    let physical:KinematicState
    let drive:[Double]
    let count:Int
    let reserved:Int
    init(physical:KinematicState,drive:[Double],count:Int,reserved:Int) {
        self.physical=physical;self.drive=drive;self.count=count;self.reserved=reserved
    }
}
