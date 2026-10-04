
public enum MechanicalBody: Equatable, Sendable {
    case planar(BodyRecord2D)
    case spatial(BodyRecord3D)

    public var id: EntityID { switch self { case .planar(let body): body.id; case .spatial(let body): body.id } }
    public var frame: EntityID { switch self { case .planar(let body): body.frame; case .spatial(let body): body.frame } }
    public var mode: BodyMotionMode { switch self { case .planar(let body): body.mode; case .spatial(let body): body.mode } }
    public var representations: BodyRepresentations { switch self { case .planar(let body): body.representations; case .spatial(let body): body.representations } }
    public var dimension: KinematicDimension { switch self { case .planar: .planar; case .spatial: .spatial } }

    public func kinematicBody() throws -> KinematicBody {
        switch self { case .planar(let body): try KinematicBody(body: body); case .spatial(let body): KinematicBody(body: body) }
    }
}
