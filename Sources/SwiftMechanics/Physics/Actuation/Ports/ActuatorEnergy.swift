public struct ActuatorEnergy: Equatable, Sendable {
    public let sourceWork:Double,mechanicalWork:Double,storedBefore:Double,storedAfter:Double,physicalLoss:Double,numericalLoss:Double,balanceResidual:Double
    internal init(sourceWork:Double,mechanicalWork:Double,storedBefore:Double,storedAfter:Double,physicalLoss:Double,numericalLoss:Double,tolerance:NumericalTolerance) throws(ActuationError) {
        guard sourceWork.isFinite,mechanicalWork.isFinite,storedBefore.isFinite,storedAfter.isFinite,physicalLoss.isFinite,numericalLoss.isFinite,
              storedBefore >= 0,storedAfter >= 0,physicalLoss >= 0,numericalLoss >= 0 else { throw .nonfiniteResult }
        let residual=try actuationFinite(sourceWork-mechanicalWork-(storedAfter-storedBefore)-physicalLoss-numericalLoss)
        let scale=max(abs(sourceWork),max(abs(mechanicalWork),max(storedBefore,max(storedAfter,max(physicalLoss,numericalLoss)))))
        let accepted:Bool
        do throws(CoreError) { accepted=try tolerance.contains(error:residual,scale:scale) } catch { throw .core(error) }
        guard accepted else { throw .residualMismatch }
        self.sourceWork=sourceWork;self.mechanicalWork=mechanicalWork;self.storedBefore=storedBefore;self.storedAfter=storedAfter;self.physicalLoss=physicalLoss;self.numericalLoss=numericalLoss;balanceResidual=residual
    }
}
