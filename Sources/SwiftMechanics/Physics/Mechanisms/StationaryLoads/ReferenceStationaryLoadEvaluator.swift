public struct ReferenceStationaryLoadEvaluator:StationaryLoadEvaluating {
    public init() {}
    public func evaluate(_ program:StationaryLoadProgram,catalog:StationaryLoadCatalog,physical:KinematicState,work:inout LoadWork) throws(StationaryLoadError) -> StationaryLoadSample {
        let n=catalog.layout.scales.count
        guard physical.revision == catalog.model.revision,physical.q.count == n,physical.v.count == n,
              catalog.programs.contains(program) else { throw .staleBinding }
        do throws(LoadError) { try work.reserve(scalars:n) } catch { throw .loads(error) }
        var force=[Double](repeating:0,count:n),potential=0.0,dissipation=0.0
        for term in program.terms {
            guard let index=catalog.layout.coordinateIDs.firstIndex(of:term.coordinateID) else { throw .staleBinding }
            do throws(LoadError) {
                let response=try ScalarLoadEvaluator().evaluate(term.law,coordinate:physical.q[index],rate:physical.v[index],work:&work)
                force[index]+=try response.total();potential+=response.potentialEnergy ?? 0;dissipation+=response.dissipatedPower
            } catch { throw .loads(error) }
            guard force[index].isFinite,potential.isFinite,dissipation.isFinite else { throw .invalidInput }
        }
        do throws(DynamicsError) { return StationaryLoadSample(physical:physical,program:program,contribution:try GeneralizedForceContribution(values:force,channel:.applied,potentialEnergy:potential,dissipatedPower:dissipation),support:catalog.dependencyCoordinateIDs) }
        catch { throw .invalidInput }
    }
}
