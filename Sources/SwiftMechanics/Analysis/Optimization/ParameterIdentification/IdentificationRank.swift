internal enum IdentificationRank {
    static func prove(_ design:[Double],rows:Int,policy:IdentificationPolicy,work:inout NumericalWork) throws(IdentificationCause) {
        try IdentificationArithmetic.charge(try IdentificationArithmetic.product(rows,2),policy,&work)
        var pivot=0.0,index=0
        for i in design.indices {
            try IdentificationArithmetic.charge(1,policy,&work)
            if abs(design[i]) > pivot { pivot=abs(design[i]);index=i }
        }
        guard pivot > 0 else { throw .unidentifiable(rank:0,identifiableDirection:[],nullDirection:[1,0,0,1],originalNullResidual:0) }
        guard pivot > policy.rankThreshold else { throw .rankIndeterminate(pivot:pivot,threshold:policy.rankThreshold) }
        let column=index%2,other=1-column,row=index/2,value=design[index]
        let first=try IdentificationArithmetic.finite(design[2*row]/value),second=try IdentificationArithmetic.finite(design[2*row+1]/value)
        var next=0.0
        for i in 0..<rows {
            try IdentificationArithmetic.charge(4,policy,&work)
            let residual=try IdentificationArithmetic.finite(design[2*i+other]-design[2*i+column]*(column == 0 ? second : first))
            next=max(next,abs(residual))
        }
        if next > 0 {
            guard next > policy.rankThreshold else { throw .rankIndeterminate(pivot:next,threshold:policy.rankThreshold) }
            return
        }
        let null=column == 0 ? [-second,1.0] : [1.0,-first]
        var residual=0.0
        for i in 0..<rows {
            try IdentificationArithmetic.charge(4,policy,&work)
            residual=max(residual,abs(try IdentificationArithmetic.finite(design[2*i]*null[0]+design[2*i+1]*null[1])))
        }
        guard residual <= policy.rankThreshold else { throw .originalEvidenceRejected }
        throw .unidentifiable(rank:1,identifiableDirection:[first,second],nullDirection:null,originalNullResidual:residual)
    }
}
