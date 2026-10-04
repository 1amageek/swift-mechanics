
public protocol TransmissionConstitutiveEvaluating: Sendable {
    func shaft(_ binding: TransmissionPortBinding,layout: ConstraintCoordinateLayout,position: Double,velocity: Double,acceleration: Double,law: ShaftLaw,
               policy: TransmissionPolicy,work: inout NumericalWork,constraintWork: inout NumericalWork) throws(TransmissionError) -> ShaftResponse
    func initializeBacklash(_ network: CompiledTransmissionNetwork,rowIndex: Int,position: [Double],time: Double,law: BacklashLaw,
                            policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> BacklashContinuation
    func backlash(_ network: CompiledTransmissionNetwork,rowIndex: Int,position: [Double],velocity: [Double],time: Double,law: BacklashLaw,accepted: BacklashContinuation,
                  policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> BacklashResponse
    func drag(_ binding: TransmissionPortBinding,layout: ConstraintCoordinateLayout,velocity: Double,law: DirectionalDragLaw,
              policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> DirectionalDragResponse
}
