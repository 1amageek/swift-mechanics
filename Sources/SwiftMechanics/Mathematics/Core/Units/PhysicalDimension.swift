public struct PhysicalDimension: Equatable, Hashable, Sendable {
    public let length: Int8
    public let mass: Int8
    public let time: Int8
    public let angle: Int8
    public let electricCurrent: Int8
    public let temperature: Int8
    public let amount: Int8
    public let luminousIntensity: Int8
    public init(length: Int8 = 0, mass: Int8 = 0, time: Int8 = 0, angle: Int8 = 0, electricCurrent: Int8 = 0, temperature: Int8 = 0, amount: Int8 = 0, luminousIntensity: Int8 = 0) {
        self.length = length
        self.mass = mass
        self.time = time
        self.angle = angle
        self.electricCurrent = electricCurrent
        self.temperature = temperature
        self.amount = amount
        self.luminousIntensity = luminousIntensity
    }
    public static let dimensionless = PhysicalDimension()
    public static let length = PhysicalDimension(length: 1)
    public static let mass = PhysicalDimension(mass: 1)
    public static let time = PhysicalDimension(time: 1)
    public static let angle = PhysicalDimension(angle: 1)
    public static let temperature = PhysicalDimension(temperature: 1)
    public static let electricCurrent = PhysicalDimension(electricCurrent: 1)
    public static let velocity = PhysicalDimension(length: 1, time: -1)
    public static let acceleration = PhysicalDimension(length: 1, time: -2)
    public static let force = PhysicalDimension(length: 1, mass: 1, time: -2)
    public static let energy = PhysicalDimension(length: 2, mass: 1, time: -2)
    public static let pressure = PhysicalDimension(length: -1, mass: 1, time: -2)
    public static let voltage = PhysicalDimension(length: 2, mass: 1, time: -3, electricCurrent: -1)
    public static let resistance = PhysicalDimension(length: 2, mass: 1, time: -3, electricCurrent: -2)

    public func multiplied(by other: PhysicalDimension) throws(CoreError) -> PhysicalDimension {
        func sum(_ a: Int8, _ b: Int8) throws(CoreError) -> Int8 {
            let (value, overflow) = a.addingReportingOverflow(b)
            guard !overflow else { throw .dimensionExponentOverflow }
            return value
        }
        return try PhysicalDimension(
            length: sum(length, other.length),
            mass: sum(mass, other.mass),
            time: sum(time, other.time),
            angle: sum(angle, other.angle),
            electricCurrent: sum(electricCurrent, other.electricCurrent),
            temperature: sum(temperature, other.temperature),
            amount: sum(amount, other.amount),
            luminousIntensity: sum(luminousIntensity, other.luminousIntensity)        )
    }
}
