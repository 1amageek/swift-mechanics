/// Sealed sufficient allocation authority. Original multiplier nullity is not removed.
public final class GeometricPhysicalAllocationWitness: Sendable {
    public let rows: GeometricPhysicalRowWitness
    public let originalRank: ConstraintRankEvidence
    public let activeRowIDs: [UInt64]
    public let zeroRowIDs: [UInt64]
    /// Conditional on a compatible known generalized reaction and the original numerical rank policy.
    public let physicalWrenchesUnique: Bool = true
    public var multipliersUnique: Bool { originalRank.reactionsUnique }
    private init(rows:GeometricPhysicalRowWitness,rank:ConstraintRankEvidence,active:[UInt64],zero:[UInt64]) {
        self.rows=rows;originalRank=rank;activeRowIDs=active;zeroRowIDs=zero
    }
    @inline(never)
    internal static func make(_ system:GeometricConstraintSystem,state:KinematicState,supplied:GeometricPhysicalRowWitness,
                              policy:GeometricPhysicalAllocationPolicy,work:inout NumericalWork) throws(GeometricPhysicalAllocationError) -> GeometricPhysicalAllocationWitness {
        try check(policy)
        let rows:GeometricPhysicalRowWitness
        do throws(GeometricConstraintError) {
            rows=try GeometricPhysicalRowAcceptance.validated(supplied,system:system,state:state,policy:policy.rows,work:&work)
        } catch { throw .geometry(error) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): This additive certificate admits reduced planar physical rows only. Spatial and more general physical-nullspace quotient certificates require separate evidence before publication.
        guard rows.dimension == .planar,rows.fidelity == .reducedPlanarBodyPointCovectors else { throw .geometry(.unsupportedDomain) }
        let n=system.layout.scales.count,m=rows.rows.count,b=system.model.tree.bodies.count
        do throws(NumericalError) {
            let width=try NumericalWork.sum(n,1)
            let retained=try NumericalWork.sum(system.scalarStorage,NumericalWork.sum(NumericalWork.product(1024,NumericalWork.product(b,width)),NumericalWork.product(128,NumericalWork.product(m,width))))
            let rankStorage=try NumericalWork.sum(NumericalWork.product(2,NumericalWork.product(m,n)),NumericalWork.sum(NumericalWork.product(3,n),NumericalWork.product(4,m)))
            try work.requireStorage(NumericalWork.sum(retained,NumericalWork.sum(rankStorage,NumericalWork.product(2,m))))
        } catch { throw .numerical(error) }
        let rank:ConstraintRankEvidence
        do throws(ConstraintError) { rank=try WeightedConstraintAssembler().rank(rows.original.velocity,policy:policy.rank,work:&work) }
        catch { throw .constraint(error) }
        var active:[UInt64]=[],zero:[UInt64]=[]
        active.reserveCapacity(m);zero.reserveCapacity(m)
        var selectedIndex=0
        for i in 0..<m {
            try check(policy)
            do throws(NumericalError) { try work.chargeOperations(try NumericalWork.sum(32,n)) } catch { throw .numerical(error) }
            let row=rows.rows[i]
            let physicalZero=row.first.linearGradient == .zero && row.first.angularGradient == .zero &&
                row.second.linearGradient == .zero && row.second.angularGradient == .zero
            let independent=selectedIndex < rank.independentRows.count && rank.independentRows[selectedIndex] == i
            if independent { selectedIndex += 1 }
            if physicalZero {
                guard !independent else { throw .ambiguousPhysicalRow(row:row.rowID) }
                for j in 0..<n {
                    guard rows.original.velocity.rows[i*n+j] == 0 else { throw .ambiguousPhysicalRow(row:row.rowID) }
                }
                zero.append(row.rowID)
            } else {
                // FIXME(INCOMPLETE_IMPLEMENTATION): Active dependent physical paths are not certified by this sufficient condition. No representative multiplier may establish unique physical allocation until a broader original physical-nullspace proof exists.
                guard independent else { throw .ambiguousPhysicalRow(row:row.rowID) }
                active.append(row.rowID)
            }
        }
        guard selectedIndex == rank.independentRows.count,active.count == rank.rank,
              zero == rank.dependentRowIDs else { throw .staleSource }
        try check(policy)
        return GeometricPhysicalAllocationWitness(rows:rows,rank:rank,active:active,zero:zero)
    }
    private static func check(_ policy:GeometricPhysicalAllocationPolicy) throws(GeometricPhysicalAllocationError) {
        guard !Task.isCancelled,!policy.rows.evaluation.isCancelled(),!policy.rank.evaluation.isCancelled() else { throw .cancelled }
    }
}
