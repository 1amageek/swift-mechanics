@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension LoadedCheckpointedMechanismSleep {
    @inline(never)
    internal func restProof(physical:KinematicState,history:LoadedMechanismSleepHistory,equation:any StationaryAffineMotionComputing,execution:any StationaryLoadExecuting,work:inout NumericalWork) throws(RuntimeFailure) -> LoadedSleepRestProof? {
        try check()
        let h=history.mechanics
        guard physical.q == h.position,physical.v == h.velocity,physical.time == h.acceptedTime else { throw RuntimeFailure(.invalidState,message:"Loaded proof accepted physical source differs.") }
        guard physical.v.allSatisfy({$0 == 0}) else { return nil }
        try numerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.product(4,physical.v.count)) }
        if let proof=memo.read(position:physical.q,drive:h.drive,selection:history.selection) { return proof }
        let motion=try equation.loadedMotion(physical:physical,selection:history.selection,drive:h.drive,execution:execution,work:&work)
        guard motion.motion.values.allSatisfy({$0 == 0}) else { return nil }
        return try restMetric(motion,physical:physical,history:history,work:&work)
    }
    @inline(never)
    private func restMetric(_ motion:StationaryAffineMotion,physical:KinematicState,history:LoadedMechanismSleepHistory,work:inout NumericalWork) throws(RuntimeFailure) -> LoadedSleepRestProof? {
        let n=physical.v.count,square=try numerical { () throws(NumericalError) in try NumericalWork.product(n,n) }
        let mass=motion.system.massMatrix
        guard mass.count == square else { throw RuntimeFailure(.invalidState,message:"Loaded kinetic metric shape differs.") }
        try numerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(square,motion.system.scalarStorage)) }
        var factor=[Double](repeating:0,count:square)
        for i in 0..<n {
            try check()
            for j in 0...i {
                try numerical { () throws(NumericalError) in try work.chargeOperations(3) }
                guard mass[i*n+j].isFinite,mass[i*n+j] == mass[j*n+i] else { throw RuntimeFailure(.invalidState,message:"Loaded kinetic metric is not symmetric finite.") }
                var value=mass[i*n+j]
                for k in 0..<j { try numerical { () throws(NumericalError) in try work.chargeOperations(2) };value-=factor[i*n+k]*factor[j*n+k] }
                guard value.isFinite else { throw RuntimeFailure(.invalidState,message:"Loaded SPD arithmetic is nonfinite.") }
                if i == j { guard value > 0 else { throw RuntimeFailure(.invalidState,message:"Loaded kinetic metric is not positive definite.") };factor[i*n+j]=value.squareRoot() }
                else { factor[i*n+j]=value/factor[j*n+j] }
            }
        }
        let decision:MechanismSleepDecision
        do throws(MechanismError) { decision=try ConnectedMechanismSleep().evaluate(motion.system,sample:motion.rows,wakeCoordinateIDs:[],policy:policy.thresholds,work:&work) }
        catch { throw RuntimeFailure(.invalidState,message:"Loaded original energy/velocity criterion failed.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        guard decision.asleep.allSatisfy({$0}) else { return nil }
        var groups:[[Int]]=[]
        for group in decision.groups {
            var indices:[Int]=[]
            for id in group { guard let index=constraints.layout.coordinateIDs.firstIndex(of:id) else { throw RuntimeFailure(.invalidState,message:"Loaded connected criterion returned unknown coordinate.") };indices.append(index) }
            guard !indices.isEmpty else { throw RuntimeFailure(.invalidState,message:"Loaded connected group is empty.") };groups.append(indices)
        }
        let proof=LoadedSleepRestProof(position:physical.q,drive:history.mechanics.drive,selection:history.selection,groups:groups)
        memo.store(proof);return proof
    }
    internal func numerical<T>(_ operation:() throws(NumericalError) -> T) throws(RuntimeFailure) -> T {
        do throws(NumericalError) { return try operation() } catch { throw RuntimeFailure(error == .cancelled ? .cancelled : .capacityExceeded,message:"Loaded sleep numerical work/capacity failed.") }
    }
}
