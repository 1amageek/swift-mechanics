/// Source-bound instantaneous generalized momentum input, in SI units conjugate to each physical q.
public struct MechanismSleepImpulse:Sendable {
    public let model:ModelStamp
    public let time:Double
    public let acceptedSequence:UInt64
    public let layout:ConstraintCoordinateLayout
    public let values:[Double]
    public init(model:ModelStamp,time:Double,acceptedSequence:UInt64,layout:ConstraintCoordinateLayout,values:[Double]) throws(RuntimeFailure) {
        guard time.isFinite,values.count == layout.scales.count,values.allSatisfy({$0.isFinite}),values.contains(where:{$0 != 0}),layout.revision == model.revision else {
            throw RuntimeFailure(.invalidInput,message:"Generalized impulse requires finite nonzero SI momentum and complete source binding.")
        }
        self.model=model;self.time=time;self.acceptedSequence=acceptedSequence;self.layout=layout;self.values=values
    }
}
