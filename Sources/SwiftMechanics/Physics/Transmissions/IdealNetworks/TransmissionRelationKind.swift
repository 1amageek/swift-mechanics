public enum TransmissionRelationKind: Sendable {
    case externalGear(first: Int, second: Int, firstTeeth: UInt32, secondTeeth: UInt32, phase: Double, phaseScale: Double)
    case internalGear(first: Int, second: Int, firstTeeth: UInt32, secondTeeth: UInt32, phase: Double, phaseScale: Double)
    case rackPinion(pinion: Int, rack: Int, radius: Double, travelSign: Int8, phase: Double, phaseScale: Double)
    case rigidShaft(first: Int, second: Int, phase: Double, phaseScale: Double)
    case pulley(first: Int, second: Int, firstRadius: Double, secondRadius: Double, crossed: Bool, phase: Double, phaseScale: Double)
    case planetary(sun: Int, ring: Int, carrier: Int, sunTeeth: UInt32, ringTeeth: UInt32, phase: Double, phaseScale: Double)
    case unsupported(TransmissionDeferredFidelity)
}
