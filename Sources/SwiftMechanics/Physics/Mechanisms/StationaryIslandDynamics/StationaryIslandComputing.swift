public protocol StationaryIslandComputing: Sendable {
    func motion(program: StationaryIslandProgram, islandID: UInt64, physical: KinematicState,
                work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandMotion
    func certifyRest(program: StationaryIslandProgram, islandID: UInt64, physical: KinematicState,
                     thresholds: MechanismSleepPolicy, work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandRestCertificate?
    func associateRest(certificate: StationaryIslandRestCertificate, program: StationaryIslandProgram,
                       physical: KinematicState, work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> Bool
}
