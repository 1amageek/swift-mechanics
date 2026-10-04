public protocol CADInvoluteGearQuerying: CADGeometryQuerying {
    func involuteGear(occurrenceID: String, expected: CADSourceIdentity,
                      work: inout CADAdapterWork) throws(CADAdapterError) -> CADInvoluteGearWitness
}
