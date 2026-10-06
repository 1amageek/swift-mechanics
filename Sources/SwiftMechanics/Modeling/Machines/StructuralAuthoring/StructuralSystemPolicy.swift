public struct StructuralSystemPolicy: Sendable {
    public let coordinates: [StructuralCoordinateBinding]
    public let timeScale: Double
    public let minimumTime: Double
    public let maximumTime: Double
    public let maximumDeclarations: Int
    public let networkID: UInt64
    public let transmission: TransmissionPolicy
    public let loadCapacity: StationaryLoadCapacity
    public let loadSelection: StationaryLoadSelection
    public let motorPowerTolerance: NumericalTolerance
    public init(coordinates: [StructuralCoordinateBinding], timeScale: Double,
                minimumTime: Double, maximumTime: Double, maximumDeclarations: Int,
                networkID: UInt64, transmission: TransmissionPolicy,
                loadCapacity: StationaryLoadCapacity, loadSelection: StationaryLoadSelection,
                motorPowerTolerance: NumericalTolerance) throws(StructuralSystemFailure) {
        guard timeScale.isFinite, timeScale > 0, minimumTime.isFinite, maximumTime.isFinite,
              minimumTime <= maximumTime, maximumDeclarations >= 0, loadSelection.revision > 0 else { throw .invalidInput }
        self.coordinates = coordinates; self.timeScale = timeScale
        self.minimumTime = minimumTime; self.maximumTime = maximumTime
        self.maximumDeclarations = maximumDeclarations; self.networkID = networkID
        self.transmission = transmission; self.loadCapacity = loadCapacity
        self.loadSelection = loadSelection
        self.motorPowerTolerance = motorPowerTolerance
    }
}
