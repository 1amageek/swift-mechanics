public struct ToothContactPair: Equatable, Sendable {
    public let key: String
    public let firstProxy: Int
    public let secondProxy: Int
    public let law: ContactLawPair
    public init(key: String, firstProxy: Int, secondProxy: Int, law: ContactLawPair) throws(ToothContactError) {
        guard !key.isEmpty, firstProxy >= 0, secondProxy >= 0, firstProxy != secondProxy else { throw .invalidInput }
        self.key=key; self.firstProxy=firstProxy; self.secondProxy=secondProxy; self.law=law
    }
}
