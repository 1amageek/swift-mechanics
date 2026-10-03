import MechanicsCore
import MechanicsJoints
import MechanicsNumerics
import MechanicsConstraints
import MechanicsNonlinear

public struct AffineTransmissionOperator: TransmissionNetworkOperating {
    private let mapper: any TransmissionPortMapping
    private let assembler: any ConstraintAssembling
    public init(assembler: any ConstraintAssembling = WeightedConstraintAssembler(), mapper: any TransmissionPortMapping = AxialTransmissionMapper()) { self.assembler=assembler; self.mapper=mapper }
    @inline(never)
    public func assemble(_ network: CompiledTransmissionNetwork, initialPosition: [Double], time: Double, assemblyPolicy: ConstraintSolvePolicy,
                         policy: TransmissionPolicy, work: inout NumericalWork, constraintWork: inout NumericalWork) throws(TransmissionError) -> TransmissionNetworkSolution {
        try admit(network,policy:policy,work:&work)
        let solved: ConstraintAssemblySolution
        do { solved=try assembler.assemble(network.equations,initialPosition:initialPosition,time:time,policy:assemblyPolicy,work:&constraintWork) }
        catch {
            let unavailable: Bool
            switch error {
            case .nonlinear(let failure): unavailable=failure.failedSupplierWorkUnavailable
            case .linear(_,let missing): unavailable=missing
            // Successful nested nonlinear work can be discarded by a later assembly acceptance failure.
            default: unavailable=true
            }
            throw .assembly(error,failedSupplierWorkUnavailable:unavailable)
        }
        let residual=try phases(network,position:solved.position,policy:policy,work:&work)
        try TransmissionArithmetic.check(policy)
        return TransmissionNetworkSolution(assembly:solved,originalPhysicalPhaseResidual:residual)
    }
    @inline(never)
    public func idealEfforts(_ network: CompiledTransmissionNetwork, position: [Double], velocity: [Double], normalizedEnergyMultipliers: [Double],
                             policy: TransmissionPolicy, work: inout NumericalWork) throws(TransmissionError) -> TransmissionIdealResponse {
        try admit(network,policy:policy,work:&work)
        let n=network.equations.layout.scales.count, m=network.physicalRows.count
        guard velocity.count == n, normalizedEnergyMultipliers.count == m else { throw .invalidDimensions }
        try TransmissionArithmetic.storage(TransmissionArithmetic.sum(n,TransmissionArithmetic.product(64,network.ports.count)),&work)
        let phaseResidual=try phases(network,position:position,policy:policy,work:&work)
        var effort=[Double](repeating:0,count:n), speedResidual=0.0, phasePower=0.0
        for row in 0..<m {
            try TransmissionArithmetic.check(policy)
            let physical=network.physicalRows[row], lambda=normalizedEnergyMultipliers[row]
            try TransmissionArithmetic.charge(1,&work); guard lambda.isFinite else { throw .invalidInput }
            var rate=0.0
            for i in 0..<n {
                try TransmissionArithmetic.charge(6,&work); guard velocity[i].isFinite else { throw .invalidInput }
                rate=try TransmissionArithmetic.finite(rate+physical.coefficients[i]*velocity[i])
                effort[i]=try TransmissionArithmetic.finite(effort[i]+lambda*physical.coefficients[i]/physical.phaseScale)
            }
            try TransmissionArithmetic.charge(5,&work)
            let normalized=try TransmissionArithmetic.finite(abs(rate)*network.equations.layout.timeScale/physical.phaseScale)
            guard normalized <= policy.originalTolerance else { throw .originalResidual(rowID:physical.id,value:normalized) }
            speedResidual=max(speedResidual,normalized); phasePower=try TransmissionArithmetic.finite(phasePower+lambda*rate/physical.phaseScale)
        }
        let mapped=try mapper.map(network.ports,layout:network.equations.layout,efforts:effort,velocity:velocity,policy:policy,work:&work)
        try TransmissionArithmetic.charge(3,&work)
        let residual=try TransmissionArithmetic.finite(max(abs(mapped.totalPower),abs(mapped.totalPower-phasePower))/policy.powerScale)
        guard residual <= policy.powerTolerance else { throw .powerResidual(value:residual) }
        try TransmissionArithmetic.check(policy)
        return TransmissionIdealResponse(generalizedEfforts:effort,ports:mapped.ports,originalPhaseResidual:phaseResidual,originalSpeedResidual:speedResidual,totalPower:mapped.totalPower,powerResidual:residual)
    }
    @inline(never)
    internal func phases(_ network: CompiledTransmissionNetwork,position: [Double],policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> Double {
        let n=network.equations.layout.scales.count
        guard position.count == n else { throw .invalidDimensions }
        for i in 0..<n {
            try TransmissionArithmetic.charge(3,&work)
            guard position[i].isFinite, position[i] >= network.equations.minimumPosition[i], position[i] <= network.equations.maximumPosition[i] else { throw .outsideDomain }
        }
        var residual=0.0
        for row in network.physicalRows {
            try TransmissionArithmetic.check(policy)
            var value = -row.phase
            for i in 0..<n { try TransmissionArithmetic.charge(2,&work); value=try TransmissionArithmetic.finite(value+row.coefficients[i]*position[i]) }
            try TransmissionArithmetic.charge(1,&work)
            let normalized=try TransmissionArithmetic.finite(abs(value)/row.phaseScale)
            guard normalized <= policy.originalTolerance else { throw .originalResidual(rowID:row.id,value:normalized) }; residual=max(residual,normalized)
        }
        return residual
    }
    private func admit(_ network: CompiledTransmissionNetwork,policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) {
        guard network.modelRevision == policy.expectedModelRevision, network.physicalRows.count <= policy.maximumRelations else { throw .staleBinding }
        try TransmissionArithmetic.validate(network.ports,layout:network.equations.layout,policy:policy,work:&work)
    }
}
