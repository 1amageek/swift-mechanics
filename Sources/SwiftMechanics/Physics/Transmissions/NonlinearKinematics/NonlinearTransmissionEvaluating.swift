/// Ideal scalar geometry/profile mapping with explicit SI coordinate kinds and exact derivatives.
public protocol NonlinearTransmissionEvaluating: Sendable {
    func evaluate(inputCoordinate: Double) throws(NonlinearTransmissionError) -> NonlinearTransmissionSample
}
