import SwiftMechanics

public struct CADGearPairBinding: Sendable {
    public let geometry: CADGeometryAdmission
    public let model: CompiledMechanicalModel
    public let state: CompiledKinematicState
    public let first: CADInvoluteGearWitness
    public let second: CADInvoluteGearWitness
    public let firstEndFace: CADSurfaceWitness
    public let secondEndFace: CADSurfaceWitness
    public let request: CADGearPairRequest
    public let network: CompiledTransmissionNetwork

    init(admission: _CADGearPairAdmission) {
        geometry = admission.geometry; model = admission.model; state = admission.state
        first = admission.first; second = admission.second
        firstEndFace = admission.firstEndFace; secondEndFace = admission.secondEndFace
        request = admission.request; network = admission.network
    }

    public func validating(source: CADSourceIdentity, model: ModelStamp) throws(CADGearBindingError) {
        guard source == geometry.identity else { throw .staleSource }
        guard model == self.model.stamp else { throw .staleModel }
    }
}
