public protocol ContactMaterialPairing: Sendable {
    func combine(first: ContactMaterial, second: ContactMaterial, selection: ContactNormalSelection,
                 lossPolicy: ContactLossPolicy, resistanceRadius: Double, override: ContactPairOverride?,
                 work: inout ContactWork) throws(ContactLawError) -> ContactLawPair
}
