internal struct ToothPairSample: Sendable {
    let observation: ToothContactObservation
    let firstLoad: BodyWrenchContribution
    let secondLoad: BodyWrenchContribution
}
