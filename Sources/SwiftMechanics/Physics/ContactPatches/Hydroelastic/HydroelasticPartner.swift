public enum HydroelasticPartner: Sendable {
    case field(HydroelasticCellSelection)
    case rigidPlane(HydroelasticPlaneSelection)
    case wholeMeshDiscovery, arbitrarySurface, evolution
}
