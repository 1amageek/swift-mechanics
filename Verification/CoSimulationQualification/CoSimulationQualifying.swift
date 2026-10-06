public protocol CoSimulationQualifying: Sendable {
    func run(_ selected: CoSimulationQualificationCase) throws
}
