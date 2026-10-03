import MechanicsNumerics
import MechanicsConstraints
import MechanicsDynamics
import MechanicsJoints

public struct ConnectedMechanismSleep: MechanismSleepEvaluating {
    public init() {}
    public func evaluate(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,wakeCoordinateIDs:[UInt64],policy:MechanismSleepPolicy,
                         work:inout NumericalWork) throws(MechanismError) -> MechanismSleepDecision {
        let n=system.velocityCount,m=sample.rowIDs.count
        guard n > 0,n <= policy.maximumCoordinates,m <= policy.maximumCoordinates,wakeCoordinateIDs.count <= n else { throw .capacityExceeded }
        let square=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(n,n) }
        let entries=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(m,n) }
        guard sample.layout.scales.count == n,sample.layout.coordinateIDs.count == n,sample.rows.count == entries,
              system.massMatrix.count == square,sample.layout.revision == system.input.snapshot.tree.revision else { throw .staleBinding }
        try MechanismArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(square,try NumericalWork.product(8,n))) }
        var edges=[Bool](repeating:false,count:square),group=[Int](repeating:-1,count:n),groups:[[UInt64]]=[]
        for i in 0..<n {
            try check(policy);try MechanismArithmetic.charge(4,&work)
            guard sample.layout.scales[i].isFinite,sample.layout.scales[i] > 0,system.input.velocity[i].isFinite else { throw .invalidInput }
            for j in 0..<i { try MechanismArithmetic.charge(1,&work);guard sample.layout.coordinateIDs[i] != sample.layout.coordinateIDs[j] else { throw .invalidInput } }
            for j in 0..<n {
                try MechanismArithmetic.charge(2,&work)
                guard system.massMatrix[i*n+j].isFinite else { throw .invalidInput }
                if system.massMatrix[i*n+j] != 0 { edges[i*n+j]=true;edges[j*n+i]=true }
            }
        }
        for row in 0..<m { for i in 0..<n {
            try check(policy);try MechanismArithmetic.charge(1,&work)
            guard sample.rows[row*n+i].isFinite else { throw .invalidInput }
            if sample.rows[row*n+i] != 0 { for j in 0..<n {
                try MechanismArithmetic.charge(1,&work)
                if sample.rows[row*n+j] != 0 { edges[i*n+j]=true;edges[j*n+i]=true }
            } }
        } }
        for id in wakeCoordinateIDs {
            try MechanismArithmetic.charge(n,&work)
            guard sample.layout.coordinateIDs.contains(id) else { throw .invalidInput }
        }
        var energies:[Double]=[],sleeping:[Bool]=[]
        for seed in 0..<n where group[seed] == -1 {
            let index=groups.count;var queue=[seed],cursor=0;group[seed]=index
            while cursor < queue.count {
                try check(policy);let i=queue[cursor];cursor+=1
                for j in 0..<n { try MechanismArithmetic.charge(1,&work);if edges[i*n+j],group[j] == -1 { group[j]=index;queue.append(j) } }
            }
            var energy=0.0,speed=0.0,wake=false,ids:[UInt64]=[]
            for i in queue {
                ids.append(sample.layout.coordinateIDs[i]);try MechanismArithmetic.charge(wakeCoordinateIDs.count+3,&work)
                wake = wake || wakeCoordinateIDs.contains(sample.layout.coordinateIDs[i])
                speed=max(speed,abs(try MechanismArithmetic.finite(system.input.velocity[i]*sample.layout.timeScale/sample.layout.scales[i])))
                for j in queue { try MechanismArithmetic.charge(4,&work);energy=try MechanismArithmetic.finite(energy+0.5*system.input.velocity[i]*system.massMatrix[i*n+j]*system.input.velocity[j]) }
            }
            guard energy >= 0 else { throw .invalidInput }
            groups.append(ids);energies.append(energy);sleeping.append(!wake && speed <= policy.normalizedVelocityThreshold && energy <= policy.kineticEnergyThreshold)
        }
        try check(policy);return MechanismSleepDecision(groups:groups,asleep:sleeping,kineticEnergy:energies)
    }
    private func check(_ policy:MechanismSleepPolicy) throws(MechanismError) { guard !Task.isCancelled,!policy.isCancelled() else { throw .cancelled } }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Decisions can be computed now, but accepted dynamics omission requires checkpointed connected sleep state plus impact/actuator/topology event authority and force consistency. This callable execution gate must remain failure until actual evolution and replay prove those transitions.
    public func suspendEvolution() throws(MechanismError) -> Never { throw .unsupportedSleepExecution }
}
