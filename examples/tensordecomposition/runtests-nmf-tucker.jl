import TensorDecompositions
import dNTF

srand(2015)
a = rand(20)
b = rand(20)
W = [a b]
H = [.1 1 0 0 .1; 0 0 .1 .5 .2]
Q = [1; 2; 3]
X = W * H
tsize = (20, 5, 3)
T_orig = Array{Float64}(tsize)
T_orig[:,:,1] = X
T_orig[:,:,2] = X * 2
T_orig[:,:,3] = X * 3

# T = add_noise(T_orig, 0.6, true)
T = T_orig

sizes = [(1,1,1), (2,2,2), (2,2,1), (2,1,1), (2,1,2), (1,2,2)]
ndimensons = length(sizes[1])
nruns = length(sizes)
residues = Array{Float64}(nruns)
correlations_factors = Array{Float64}(nruns, ndimensons)
correlations = Array{Float64}(nruns, ndimensons)
T_esta = Array{Array{Float64,3}}(nruns)
tucker_spnn = Array{TensorDecompositions.Tucker{Float64,3}}(nruns)
for i in 1:nruns
	info("Core size: $(sizes[i])")
	@time tucker_spnn[i] = TensorDecompositions.spnntucker(T, sizes[i], tol=1e-7, ini_decomp=:hosvd, core_nonneg=true, verbose=false)
	T_est = TensorDecompositions.compose(tucker_spnn[i])
	T_esta[i] = T_est
	residues[i] = TensorDecompositions.rel_residue(tucker_spnn[i])
	correlations[i,1] = minimum(map((j)->minimum(map((k)->cor(T_est[:,k,j], T_orig[:,k,j]), 1:tsize[2])), 1:tsize[3]))
	correlations[i,2] = minimum(map((j)->minimum(map((k)->cor(T_est[k,:,j], T_orig[k,:,j]), 1:tsize[1])), 1:tsize[3]))
	correlations[i,3] = minimum(map((j)->minimum(map((k)->cor(T_est[k,j,:], T_orig[k,j,:]), 1:tsize[1])), 1:tsize[2]))
	println("$i - $(sizes[i]): residual $(residues[i]) correlations $(correlations[i,:])")
end

info("Relative error of decompositions:")
ibest = 1
best = Inf
for i in 1:nruns
	if residues[i] < best
		best = residues[i]
		ibest = i
	end
	println("$i - $(sizes[i]): residual $(residues[i]) correlations $(correlations[i,:])")
end

if ibest == 2 || ibest == 3 # these should be the best results; otherwise the comparison fails
	dNTF.plotcmptensor(T_orig, T_esta[ibest], 3)
	@show cor(W[:,1], tucker_spnn[ibest].factors[1][:,1])
	@show cor(W[:,2], tucker_spnn[ibest].factors[1][:,2])
	@show cor(H[1,:], tucker_spnn[ibest].factors[2][:,1])
	@show cor(H[2,:], tucker_spnn[ibest].factors[2][:,2])
	@show cor(Q, tucker_spnn[ibest].factors[3][:,1])
else
	warn("something is not correct; the best results should be #3 (or #2)")
end

if ibest != 3 # theoretically this should be the best result!!!
	ibest = 3
	dNTF.plotcmptensor(T_orig, T_esta[ibest], 3)
	@show cor(W[:,1], tucker_spnn[ibest].factors[1][:,1])
	@show cor(W[:,2], tucker_spnn[ibest].factors[1][:,2])
	@show cor(H[1,:], tucker_spnn[ibest].factors[2][:,1])
	@show cor(H[2,:], tucker_spnn[ibest].factors[2][:,2])
	@show cor(Q, tucker_spnn[ibest].factors[3][:,1])
	p = Gadfly.plot(
		Gadfly.Guide.title("Signal 1"),
		Gadfly.layer(x=1:length(W[:,1]), y=W[:,1], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "blue"))),
		Gadfly.layer(x=1:length(W[:,1]), y=tucker_spnn[ibest].factors[1][:,1], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "red"))))
	display(p); println()
	p = Gadfly.plot(
		Gadfly.Guide.title("Signal 2"),
		Gadfly.layer(x=1:length(W[:,2]), y=W[:,2], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "blue"))),
		Gadfly.layer(x=1:length(W[:,2]), y=tucker_spnn[ibest].factors[1][:,2], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "red"))))
	display(p); println()
	p = Gadfly.plot(
		Gadfly.Guide.title("Mixer 1"),
		Gadfly.layer(x=1:length(H[1,:]), y=H[1,:], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "blue"))),
		Gadfly.layer(x=1:length(H[1,:]), y=tucker_spnn[ibest].factors[2][:,1], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "red"))))
	display(p); println()
	p = Gadfly.plot(
		Gadfly.Guide.title("Mixer 2"),
		Gadfly.layer(x=1:length(H[2,:]), y=H[2,:], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "blue"))),
		Gadfly.layer(x=1:length(H[2,:]), y=tucker_spnn[ibest].factors[2][:,2], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "red"))))
	display(p); println()
	p = Gadfly.plot(
		Gadfly.Guide.title("Time change"),
		Gadfly.layer(x=1:length(Q), y=Q, Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "blue"))),
		Gadfly.layer(x=1:length(Q), y=tucker_spnn[ibest].factors[3][:,1], Gadfly.Geom.line, Gadfly.Theme(default_color=parse(Colors.Colorant, "red"))))
	display(p); println()
end