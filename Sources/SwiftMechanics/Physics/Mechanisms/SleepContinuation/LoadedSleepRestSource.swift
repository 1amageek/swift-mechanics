internal final class LoadedSleepRestSource:Sendable {
    let physical:KinematicState
    let history:LoadedMechanismSleepHistory
    init(physical:KinematicState,history:LoadedMechanismSleepHistory) { self.physical=physical;self.history=history }
}
