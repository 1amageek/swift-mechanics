public protocol HydroelasticQualifying: Sendable {
    func run(_ selected: HydroelasticQualificationCase) throws(HydroelasticQualificationError)
}
