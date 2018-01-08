import dNTF

srand(1)
csize = (1, 1, 1)
tsize = (5, 10, 15)
tucker_orig = dNTF.rand_tucker(csize, tsize, factors_nonneg=true, core_nonneg=true)
T_orig = TensorDecompositions.compose(tucker_orig)
T_max = maximum(T_orig)
map!(x -> x / T_max, tucker_orig.core, tucker_orig.core)
map!(x -> x / T_max, T_orig, T_orig)

# T = dNTF.add_noise(T_orig, 0.6, true)
T = T_orig

sizes = [tsize, csize]
dNTF.analysis(T, sizes; progressbar=true, tol=1e-8, max_iter=1000)
dNTF.analysis(T, [1]; tol=1e-8, max_iter=1000)