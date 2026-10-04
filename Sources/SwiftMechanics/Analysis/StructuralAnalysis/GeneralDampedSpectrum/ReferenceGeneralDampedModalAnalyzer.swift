public struct ReferenceGeneralDampedModalAnalyzer: GeneralDampedModalAnalyzing, Sendable {
    private let spectrum:any ComplexSpectralSolving
    public init(spectrum:any ComplexSpectralSolving=ReferenceComplexSpectralSolver()) { self.spectrum=spectrum }
    @inline(never)
    public func modes(_ pencil:StructuralPencil,expectedBinding:StructuralBinding,policy:StructuralPolicy,
                      spectrumPolicy:ComplexSpectrumPolicy,work:inout NumericalWork) throws(GeneralDampedSpectrumFailure) -> GeneralDampedModalResult {
        var unavailable=false
        do { return try run(pencil,expected:expectedBinding,policy:policy,spectrumPolicy:spectrumPolicy,unavailable:&unavailable,work:&work) }
        catch { throw GeneralDampedSpectrumFailure(cause:error,work:work,unavailable:unavailable) }
    }
    @inline(never)
    private func run(_ pencil:StructuralPencil,expected:StructuralBinding,policy:StructuralPolicy,spectrumPolicy:ComplexSpectrumPolicy,
                     unavailable:inout Bool,work:inout NumericalWork) throws(GeneralDampedSpectrumCause) -> GeneralDampedModalResult {
        let workspace=try GeneralDampedWorkspace(pencil,expected:expected,policy:policy,work:&work)
        let spectral=try invoke(workspace,policy:spectrumPolicy,unavailable:&unavailable,work:&work)
        try GeneralDampedOriginalEvidence.supplier(spectral,matrix:workspace.companion,policy:policy,spectrumPolicy:spectrumPolicy,work:&work)
        return try GeneralDampedOriginalEvidence.publish(pencil,spectral:spectral,policy:policy,spectrumPolicy:spectrumPolicy,work:&work)
    }
    @inline(never)
    private func invoke(_ workspace:GeneralDampedWorkspace,policy:ComplexSpectrumPolicy,unavailable:inout Bool,
                        work:inout NumericalWork) throws(GeneralDampedSpectrumCause) -> ComplexSpectrumResult {
        try DampedSpectrumArithmetic.check(policy)
        let requested:NumericalBudget
        do { requested=try work.remainingBudget(reservedStorage:workspace.reserved) } catch { throw .numerical(error) }
        var nested=NumericalWork(budget:requested)
        do { try nested.chargeOperations(1) } catch { throw .numerical(error) }
        let seeded=nested
        let result:ComplexSpectrumResult
        do { result=try spectrum.solve(workspace.companion,policy:policy,work:&nested) }
        catch {
            guard nested.budget==requested,nested.operations>=seeded.operations else {
                unavailable=true
                do { try work.absorb(seeded,reservedStorage:workspace.reserved) } catch { throw .numerical(error) }
                throw .invalidSupplierLedger
            }
            do { try work.absorb(nested,reservedStorage:workspace.reserved) } catch { throw .numerical(error) }
            throw .spectral(error)
        }
        guard nested.budget==requested,nested.operations>=seeded.operations,result.work==nested else {
            unavailable=true
            do { try work.absorb(seeded,reservedStorage:workspace.reserved) } catch { throw .numerical(error) }
            throw .invalidSupplierLedger
        }
        do { try work.absorb(nested,reservedStorage:workspace.reserved) } catch { throw .numerical(error) }
        // The caller's cancellation policy is authoritative even for valid supplier data.
        try DampedSpectrumArithmetic.check(policy)
        return result
    }
}
