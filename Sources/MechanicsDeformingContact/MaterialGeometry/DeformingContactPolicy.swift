public struct DeformingContactPolicy: Sendable {
    public let maximumNodes: Int, maximumCells: Int, maximumFaces: Int, maximumContacts: Int, maximumIdentifierBytes: Int
    public let minimumVolume: Double, minimumDoubleArea: Double, lengthTolerance: Double, barycentricInterior: Double
    public let forceTolerance: Double, momentTolerance: Double, powerTolerance: Double, rotationTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumNodes: Int, maximumCells: Int, maximumFaces: Int, maximumContacts: Int, maximumIdentifierBytes: Int,
                minimumVolume: Double, minimumDoubleArea: Double, lengthTolerance: Double, barycentricInterior: Double,
                forceTolerance: Double, momentTolerance: Double, powerTolerance: Double, rotationTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(DeformingContactError) {
        guard maximumNodes > 0, maximumCells > 0, maximumFaces > 0, maximumContacts > 0, maximumIdentifierBytes > 0,
              minimumVolume.isFinite, minimumVolume > 0, minimumDoubleArea.isFinite, minimumDoubleArea > 0,
              lengthTolerance.isFinite, lengthTolerance >= 0, barycentricInterior.isFinite, barycentricInterior > 0, barycentricInterior < 1/3,
              forceTolerance.isFinite, forceTolerance >= 0, momentTolerance.isFinite, momentTolerance >= 0,
              powerTolerance.isFinite, powerTolerance >= 0, rotationTolerance.isFinite, rotationTolerance > 0 else { throw .invalidInput }
        self.maximumNodes=maximumNodes; self.maximumCells=maximumCells; self.maximumFaces=maximumFaces; self.maximumContacts=maximumContacts
        self.maximumIdentifierBytes=maximumIdentifierBytes; self.minimumVolume=minimumVolume; self.minimumDoubleArea=minimumDoubleArea
        self.lengthTolerance=lengthTolerance; self.barycentricInterior=barycentricInterior; self.forceTolerance=forceTolerance
        self.momentTolerance=momentTolerance; self.powerTolerance=powerTolerance; self.rotationTolerance=rotationTolerance; self.isCancelled=isCancelled
    }
}
