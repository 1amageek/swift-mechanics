public struct SpatialGrid: Equatable, Sendable {
    public let id:String
    public let revision:UInt64
    public let frame:EntityID
    public let source:SourceProvenance
    public let nx:Int
    public let ny:Int
    public let nz:Int
    public let count:Int
    public let lengthX:Double
    public let lengthY:Double
    public let lengthZ:Double
    public let density:Double
    public let viscosity:Double
    public let limits:SpatialLimits
    public var dx:Double { lengthX/Double(nx) }
    public var dy:Double { lengthY/Double(ny) }
    public var dz:Double { lengthZ/Double(nz) }
    public var nu:Double { viscosity/density }
    public var cellMass:Double { density*dx*dy*dz }
    public var totalMass:Double { cellMass*Double(count) }
    public init(id:String,revision:UInt64,frame:EntityID,source:SourceProvenance,nx:Int,ny:Int,nz:Int,
                lengthX:Double,lengthY:Double,lengthZ:Double,density:Double,viscosity:Double,
                limits:SpatialLimits) throws(SpatialFluidError) {
        guard nx >= 3,ny >= 3,nz >= 3 else { throw .invalidInput }
        let (plane,planeOverflow)=nx.multipliedReportingOverflow(by:ny)
        let (count,overflow)=plane.multipliedReportingOverflow(by:nz)
        guard !planeOverflow,!overflow,count < Int.max,count <= limits.maximumCells else { throw .capacity }
        var remaining=limits.maximumMetadataBytes
        for text in [id,frame.key,source.source] {
            guard !text.isEmpty else { throw .invalidInput }
            for _ in text.utf8 { guard remaining > 0 else { throw .capacity };remaining -= 1 }
        }
        guard frame.kind == .frame,lengthX.isFinite,lengthX > 0,lengthY.isFinite,lengthY > 0,
              lengthZ.isFinite,lengthZ > 0,density.isFinite,density > 0,viscosity.isFinite,viscosity > 0 else { throw .invalidInput }
        self.id=id;self.revision=revision;self.frame=frame;self.source=source;self.nx=nx;self.ny=ny;self.nz=nz;self.count=count
        self.lengthX=lengthX;self.lengthY=lengthY;self.lengthZ=lengthZ;self.density=density;self.viscosity=viscosity;self.limits=limits
        guard dx.isFinite,dx > 0,dy.isFinite,dy > 0,dz.isFinite,dz > 0,nu.isFinite,nu > 0,cellMass.isFinite,cellMass > 0,
              totalMass.isFinite,(1/dx).isFinite,(1/dy).isFinite,((1/dx)*(1/dx)).isFinite,
              ((1/dy)*(1/dy)).isFinite,((1/dx)*(1/dx)) > 0,((1/dy)*(1/dy)) > 0,(1/dz).isFinite,((1/dz)*(1/dz)).isFinite,((1/dz)*(1/dz)) > 0 else { throw .nonfinite }
    }
    public func index(i:Int,j:Int,k:Int) throws(SpatialFluidError)->Int {
        guard i >= 0,i < nx,j >= 0,j < ny,k >= 0,k < nz else { throw .invalidInput }
        return (k*ny+j)*nx+i
    }
    internal func spacing(_ axis:Int)->Double { axis == 0 ? dx : (axis == 1 ? dy : dz) }
    internal func neighbor(_ index:Int,_ axis:Int,_ positive:Bool)->Int {
        let stride=axis == 0 ? 1 : (axis == 1 ? nx : nx*ny)
        let width=axis == 0 ? nx : (axis == 1 ? ny : nz)
        let coordinate=(index/stride)%width
        if positive { return coordinate+1 == width ? index-(width-1)*stride : index+stride }
        return coordinate == 0 ? index+(width-1)*stride : index-stride
    }
}
