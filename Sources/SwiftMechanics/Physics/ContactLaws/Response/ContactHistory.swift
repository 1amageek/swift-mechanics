public struct ContactHistory: Equatable, Sendable {
    public let identity: ContactIdentity
    public let pair: ContactLawPair
    public let sequence: UInt64
    public let timeSeconds: Double
    public let firstBristleDisplacement: Double
    public let secondBristleDisplacement: Double
    public let cumulativeTangentialDissipation: Double
    internal init(identity: ContactIdentity, pair: ContactLawPair, sequence: UInt64, timeSeconds: Double,
                  firstBristleDisplacement: Double, secondBristleDisplacement: Double, cumulativeTangentialDissipation: Double) {
        self.identity=identity; self.pair=pair; self.sequence=sequence; self.timeSeconds=timeSeconds
        self.firstBristleDisplacement=firstBristleDisplacement; self.secondBristleDisplacement=secondBristleDisplacement
        self.cumulativeTangentialDissipation=cumulativeTangentialDissipation
    }
}
