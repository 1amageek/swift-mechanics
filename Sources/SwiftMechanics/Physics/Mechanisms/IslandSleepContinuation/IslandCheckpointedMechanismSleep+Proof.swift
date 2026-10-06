@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension IslandCheckpointedMechanismSleep {
    @inline(never)
    internal func proof(index:Int,physical:KinematicState,execution:IslandSleepExecution,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryIslandRestCertificate? {
        let island=program.islands[index]
        guard island.sourceCoordinateIndices.allSatisfy({physical.v[$0] == 0}) else { return nil }
        if let cached=memo.read(index) {
            let associated=try execution.invoke(integration:&work) { (local:inout StationaryIslandWork) throws(StationaryIslandFailure) in
                try dynamics.associateRest(certificate:cached,program:program,physical:physical,work:&local)
            }
            if associated { return cached }
        }
        let actual=try execution.invoke(integration:&work) { (local:inout StationaryIslandWork) throws(StationaryIslandFailure) in
            try dynamics.certifyRest(program:program,islandID:island.id,physical:physical,thresholds:policy.thresholds,work:&local)
        }
        if let actual {
            guard actual.program.binding == program.binding,actual.islandID == island.id,actual.position.count == island.sourceCoordinateIndices.count,
                  actual.kineticEnergy <= policy.thresholds.kineticEnergyThreshold,actual.normalizedVelocity <= policy.thresholds.normalizedVelocityThreshold,
                  zip(actual.position,island.sourceCoordinateIndices).allSatisfy({pair in pair.0.bitPattern == physical.q[pair.1].bitPattern}) else { throw RuntimeFailure(.invalidState,message:"Physical rest supplier returned foreign certificate.") }
        }
        memo.store(actual,at:index);return actual
    }
    @inline(never)
    internal func acceleration(physical:KinematicState,flags:[Bool],proofs:[StationaryIslandRestCertificate?],execution:IslandSleepExecution,work:inout NumericalWork) throws(RuntimeFailure) -> [Double] {
        try checkPhysical(physical);guard flags.count == program.islands.count,proofs.count == flags.count else { throw RuntimeFailure(.invalidState,message:"Prepared island authority shape differs.") }
        let reserved=try IslandSleepBits.product(4,physical.v.count)
        try execution.reserveOwned(reserved,integration:&work)
        var result=[Double](repeating:.nan,count:physical.v.count)
        for j in program.islands.indices {
            try check();let island=program.islands[j]
            if flags[j] {
                guard let proof=proofs[j] else { throw RuntimeFailure(.invalidContributor,message:"Sleeping island lost immutable operation proof.") }
                let associated=try execution.invoke(integration:&work,reserved:reserved) { (local:inout StationaryIslandWork) throws(StationaryIslandFailure) in
                    try dynamics.associateRest(certificate:proof,program:program,physical:physical,work:&local)
                }
                guard associated else { throw RuntimeFailure(.invalidState,message:"Omitted island changed exact resting law/source.") }
                for i in island.sourceCoordinateIndices { result[i]=0 }
            } else {
                let motion=try execution.invoke(integration:&work,reserved:reserved) { (local:inout StationaryIslandWork) throws(StationaryIslandFailure) in
                    try dynamics.motion(program:program,islandID:island.id,physical:physical,work:&local)
                }
                guard motion.program.binding == program.binding,motion.island.id == island.id,samePhysical(motion.physical,physical),motion.acceleration.count == island.sourceCoordinateIndices.count,motion.acceleration.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Active island motion changed source/mapping.") }
                for k in island.sourceCoordinateIndices.indices { result[island.sourceCoordinateIndices[k]]=motion.acceleration[k] }
            }
        }
        guard result.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Whole acceleration mapping is incomplete.") };return result
    }
}
