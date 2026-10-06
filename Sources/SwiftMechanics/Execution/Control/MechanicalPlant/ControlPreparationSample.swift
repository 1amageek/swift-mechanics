internal final class ControlPreparationSample: Sendable {
    let input:ControlSampleInput
    let old:ActuatorState
    let feedback:ScalarControlFeedback
    let tick:UInt64
    let q:Double
    let v:Double
    let start:Double
    let end:Double
    let dt:Double
    init(input:ControlSampleInput,old:ActuatorState,feedback:ScalarControlFeedback,tick:UInt64,q:Double,v:Double,start:Double,end:Double,dt:Double) {
        self.input=input;self.old=old;self.feedback=feedback;self.tick=tick;self.q=q;self.v=v;self.start=start;self.end=end;self.dt=dt
    }
}
