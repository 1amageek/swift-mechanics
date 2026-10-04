public struct GranularSample: Sendable {
    public let templateIndex: Int
    public let radius: Double, density: Double, mass: Double
    public let material: ModelReference
    internal init(templateIndex: Int, template: GranularDistributionTemplate, mass: Double) {
        self.templateIndex=templateIndex; radius=template.radius; density=template.density; material=template.material; self.mass=mass
    }
}
