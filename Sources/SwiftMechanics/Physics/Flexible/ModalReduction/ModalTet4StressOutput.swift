/// Identifies the reduced source state and its actual current-material, element-constant sample.
public struct ModalTet4StressOutput: Sendable {
    public let state: ModalReducedState
    public let sample: Tet4FieldSample
    /// Aggregate caller work, including modal reconstruction and the real field supplier work.
    public let numericalWork: NumericalWork
    internal init(state: ModalReducedState, sample: Tet4FieldSample, work: NumericalWork) {
        self.state = state; self.sample = sample; self.numericalWork = work
    }
}
