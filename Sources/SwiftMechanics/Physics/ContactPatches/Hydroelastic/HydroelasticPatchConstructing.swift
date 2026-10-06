public protocol HydroelasticPatchConstructing: Sendable {
    func construct(_ first: HydroelasticCellSelection, against second: HydroelasticPartner, origin: Vector3,
                   policy: HydroelasticPolicy, work: inout NumericalWork) throws(HydroelasticError) -> HydroelasticPatch
}
