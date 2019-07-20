import Distributed
Distributed.addprocs(4)

import NTFk
import TensorDecompositions
import DistributedArrays
import Random

Random.seed!(1)
trank = (2, 3, 4)
for m = 1:5
	tsize = (5 * m, 10 * m, 20 * m)
	tucker_orig = NTFk.rand_tucker(trank, tsize; core_nonneg=true, factors_nonneg=true)
	T = NTFk.compose(tucker_orig)
	dT = TensorDecompositions.distribute(T)
	tranks = [(1, 1, 1), (2, 2, 2), (3, 3, 3), (2, 3, 4), (3, 4, 5)]
	for t in tranks
		@info("TuckerSPNN Distributed Decomposition: Tensor core-size $t")
		@time tucker = TensorDecompositions.spnntucker(dT, t)
		@time T_est = NTFk.compose(tucker)
	end
end