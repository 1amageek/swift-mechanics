import SwiftMechanics

internal struct ResettingKinematicObserver:KinematicObserving {
    let throwsAfterReset:Bool
    init(throwsAfterReset:Bool=false) { self.throwsAfterReset=throwsAfterReset }
    func motion(source:ObservationSource,mount:ObservationMount,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> MountedMotionObservation {
        let value=try ReferenceKinematicObserver().motion(source:source,mount:mount,policy:policy,work:&work)
        work=NumericalWork(budget:work.budget)
        if throwsAfterReset { throw .invalidInput }
        return value
    }
    func encoder(source:ObservationSource,joint:EntityID,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> JointEncoderObservation {
        try ReferenceKinematicObserver().encoder(source:source,joint:joint,policy:policy,work:&work)
    }
}
