public struct PlanarGrid: Equatable, Sendable {
    public let id:String
    public let revision:UInt64
    public let frame:EntityID
    public let source:SourceProvenance
    public let nx:Int
    public let ny:Int
    public let count:Int
    public let lengthX:Double
    public let lengthY:Double
    public let depth:Double
    public let density:Double
    public let viscosity:Double
    public let limits:PlanarLimits
    public var dx:Double { lengthX/Double(nx) }
    public var dy:Double { lengthY/Double(ny) }
    public var nu:Double { viscosity/density }
    public var cellMass:Double { density*dx*dy*depth }
    public var totalMass:Double { cellMass*Double(count) }
    public init(id:String,revision:UInt64,frame:EntityID,source:SourceProvenance,nx:Int,ny:Int,
                lengthX:Double,lengthY:Double,depth:Double,density:Double,viscosity:Double,
                limits:PlanarLimits) throws(PlanarFluidError) {
        guard nx >= 3,ny >= 3 else { throw .invalidInput }
        let (count,overflow)=nx.multipliedReportingOverflow(by:ny)
        guard !overflow,count < Int.max,count <= limits.maximumCells else { throw .capacity }
        var remaining=limits.maximumMetadataBytes
        for text in [id,frame.key,source.source] {
            guard !text.isEmpty else { throw .invalidInput }
            for _ in text.utf8 { guard remaining > 0 else { throw .capacity };remaining -= 1 }
        }
        guard frame.kind == .frame,lengthX.isFinite,lengthX > 0,lengthY.isFinite,lengthY > 0,
              depth.isFinite,depth > 0,density.isFinite,density > 0,viscosity.isFinite,viscosity > 0 else { throw .invalidInput }
        self.id=id;self.revision=revision;self.frame=frame;self.source=source;self.nx=nx;self.ny=ny;self.count=count
        self.lengthX=lengthX;self.lengthY=lengthY;self.depth=depth;self.density=density;self.viscosity=viscosity;self.limits=limits
        guard dx.isFinite,dx > 0,dy.isFinite,dy > 0,nu.isFinite,nu > 0,cellMass.isFinite,cellMass > 0,
              totalMass.isFinite,(1/dx).isFinite,(1/dy).isFinite,((1/dx)*(1/dx)).isFinite,
              ((1/dy)*(1/dy)).isFinite,((1/dx)*(1/dx)) > 0,((1/dy)*(1/dy)) > 0 else { throw .nonfinite }
    }
    internal func index(_ i:Int,_ j:Int)->Int { j*nx+i }
    internal func left(_ k:Int)->Int { let i=k%nx;return i == 0 ? k+nx-1 : k-1 }
    internal func right(_ k:Int)->Int { let i=k%nx;return i+1 == nx ? k-nx+1 : k+1 }
    internal func below(_ k:Int)->Int { k < nx ? k+(ny-1)*nx : k-nx }
    internal func above(_ k:Int)->Int { k >= (ny-1)*nx ? k-(ny-1)*nx : k+nx }
}
