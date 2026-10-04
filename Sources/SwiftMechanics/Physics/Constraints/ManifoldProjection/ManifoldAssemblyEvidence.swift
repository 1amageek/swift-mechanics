internal final class ManifoldAssemblyEvidence: Sendable {
    let state:KinematicState
    let iteration:ManifoldIterationEvidence
    let residual:Double
    let path:Double
    let iterations:Int
    let metadata:String
    let work:NumericalWork
    init(state:KinematicState,iteration:ManifoldIterationEvidence,residual:Double,path:Double,iterations:Int,metadata:String,work:NumericalWork) {
        self.state=state;self.iteration=iteration;self.residual=residual;self.path=path;self.iterations=iterations;self.metadata=metadata;self.work=work
    }
}
