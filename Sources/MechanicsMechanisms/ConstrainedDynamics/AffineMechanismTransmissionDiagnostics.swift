import MechanicsNumerics
import MechanicsTransmissions
import MechanicsConstraints

public struct AffineMechanismTransmissionDiagnostics: MechanismTransmissionDiagnosing {
    private let transmissions:any TransmissionNetworkOperating
    public init(transmissions:any TransmissionNetworkOperating = AffineTransmissionOperator()) { self.transmissions=transmissions }
    public func diagnose(_ network:CompiledTransmissionNetwork,position:[Double],velocity:[Double],motion:ConstrainedMotion,
                         policy:TransmissionPolicy,work:inout NumericalWork) throws(MechanismError) -> TransmissionIdealResponse {
        guard case .accelerationForce=motion.temporalMeaning, network.physicalRows.count == motion.rowIDs.count,
              network.physicalRows.map({$0.id}) == motion.rowIDs,
              network.equations.layout.revision == motion.layout.revision,
              network.equations.layout.coordinateIDs == motion.layout.coordinateIDs,
              network.equations.layout.dimensions == motion.layout.dimensions,
              network.equations.layout.scales == motion.layout.scales,
              network.equations.layout.timeScale == motion.layout.timeScale else { throw .staleBinding }
        try MechanismArithmetic.charge(1,&work)
        let before=work
        var value:TransmissionIdealResponse?,failure:TransmissionError?
        do throws(TransmissionError) { value=try transmissions.idealEfforts(network,position:position,velocity:velocity,
            normalizedEnergyMultipliers:motion.rowMultipliers,policy:policy,work:&work) } catch { failure=error }
        guard MechanismArithmetic.preserved(before,work) else { work=before;throw .supplierLedgerReplaced }
        if let failure { throw .transmission(failure) }
        guard let value,value.generalizedEfforts.count == motion.generalizedReaction.count else { throw .invalidShape }
        for i in value.generalizedEfforts.indices {
            guard abs(value.generalizedEfforts[i]-motion.generalizedReaction[i]) <= policy.originalTolerance else { throw .originalMomentum(residual:abs(value.generalizedEfforts[i]-motion.generalizedReaction[i])) }
        }
        return value
    }
}

extension AffineMechanismTransmissionDiagnostics {
    // FIXME(INCOMPLETE_IMPLEMENTATION): Ideal axial networks provide shaft effort but no admitted tooth contact geometry/bearing load split. This requested diagnostic must fail until geometric application points and original force/moment balance qualify the selected fidelity.
    public func bearingLoad() throws(MechanismError) -> Never { throw .unsupportedReactionFidelity }
}
