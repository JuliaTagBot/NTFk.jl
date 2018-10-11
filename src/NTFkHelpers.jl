import Interpolations

"Convert `@sprintf` macro into `sprintf` function"
sprintf(args...) = eval(:@sprintf($(args...)))

searchdir(key::Regex, path::String = ".") = filter(x->ismatch(key, x), readdir(path))
searchdir(key::String, path::String = ".") = filter(x->contains(x, key), readdir(path))

function maximumnan(X, c...; kw...)
	maximum(X[.!isnan.(X)], c...; kw...)
end

function minimumnan(X, c...; kw...)
	minimum(X[.!isnan.(X)], c...; kw...)
end

function computestats(X, Xe, volumeindex=1:size(Xe,1), wellindex=1:size(Xe,3), timeindex=:, c=""; plot=true, quiet=true, wellnames=nothing, xaxis=1:size(Xe,2))
	m = "%-85s"
	if Xe == nothing
		info("$(NMFk.sprintf(m, c)): fails")
		return
	end
	ferr = Array{Float64}(length(volumeindex))
	wsum1 = Array{Float64}(length(wellindex))
	wsum2 = Array{Float64}(length(wellindex))
	werr = Array{Float64}(length(wellindex))
	merr = Array{Float64}(length(volumeindex))
	fcor = Array{Float64}(length(volumeindex))
	g = "%.2g"
	f = "%.2f"
	for (i, v) in enumerate(volumeindex)
		se = NMFk.sumnan(Xe[wellindex,timeindex,v])
		s =  NMFk.sumnan(X[wellindex,timeindex,v])
		# @show se
		# @show s
		ferr[i] = (se - s) / s
		for (j, w) in enumerate(wellindex)
			wsum2[j] = NMFk.sumnan(Xe[w,timeindex,v])
			wsum1[j] = NMFk.sumnan(X[w,timeindex,v])
			werr[j] = abs.(wsum2[j] - wsum1[j]) / wsum1[j]
		end
		# @show se
		# @show s
		# @show wsum2
		# @show wsum1
		# @show werr
		merr[i] = maximum(werr)
		fcor[i] = cor(vec(wsum1), vec(wsum2))
	end
	namecase = lowercase(replace(replace(c, " ", "_"), "/", "_"))
	info("$(NMFk.sprintf(m, c)): $(NMFk.sprintf(f, NMFk.vecnormnan(X[wellindex,timeindex,volumeindex] .- Xe[wellindex,timeindex,volumeindex]))) [Error: $(NMFk.sprintf(g, ferr[1])) $(NMFk.sprintf(g, ferr[2])) $(NMFk.sprintf(g, ferr[3]))] [Max error: $(NMFk.sprintf(g, merr[1])) $(NMFk.sprintf(g, merr[2])) $(NMFk.sprintf(g, merr[3]))] [Pearson: $(NMFk.sprintf(g, fcor[1])) $(NMFk.sprintf(g, fcor[2])) $(NMFk.sprintf(g, fcor[3]))]")
	plot && NTFk.plot2d(X, Xe; quiet=quiet, figuredir="results-12-18", keyword=namecase, titletext=c, wellnames=wellnames, dimname="Well", xaxis=xaxis, ymin=0, xmin=Dates.Date(2015,12,15), xmax=Dates.Date(2017,6,10), linewidth=1.5Gadfly.pt, gm=[Gadfly.Guide.manual_color_key("", ["Oil", "Gas", "Water"], ["green", "red", "blue"])], colors=["green", "red", "blue"])
end

function flatten(X::Array{T,N}, mask::BitArray{M}) where {T,N,M}
	@assert N - 1 == M
	sz = size(X)
	A = Array{T}(sum(.!mask), sz[end])
	for i = 1:sz[end]
		nt = ntuple(k->(k == N ? i : Colon()), N)
		A[:, i] = X[nt...][.!mask]
	end
	return A
end

function flatten(X::Array{T,N}, dim::Number=1) where {T,N}
	sz = size(X)
	nt = Vector{Int64}(0)
	for k = 1:N
		if (k != dim)
			push!(nt, k)
		end
	end
	A = Array{T}(*(sz[nt]...), sz[dim])
	for i = 1:sz[dim]
		nt = ntuple(k->(k == dim ? i : Colon()), N)
		A[:, i] = vec(X[nt...])
	end
	return A
end

function indicize(v, levels::Integer; rev=false)
	iv = convert(Vector{Int64}, ceil.((v .- minimum(v)) ./ (maximum(v)-minimum(v)) .* (levels - 1 ) .+ 1))
	if rev == true
		iv = (levels + 1) .- iv
	end
	return iv
end

function getcsize(case::String; resultdir::String=".")
	files = searchdir(case, resultdir)
	csize = Array{Int64}(0, 3)
	kwa = Vector{String}(0)
	for (i, f) in enumerate(files)
		m = match(Regex(string("$(case)(.*)-([0-9]+)_([0-9]+)_([0-9]+).jld")), f)
		if m != nothing
			push!(kwa, m.captures[1])
			c = parse.(Int64, m.captures[2:end])
			csize = vcat(csize, c')
		end
	end
	return csize, kwa
end

function gettensorcomponents(t::TensorDecompositions.Tucker, dim::Integer=1; core::Bool=false)
	cs = size(t.core)[dim]
	csize = TensorToolbox.mrank(t.core)
	ndimensons = length(csize)
	@assert dim >= 1 && dim <= ndimensons
	crank = csize[dim]
	Xe = Vector{Any}(cs)
	tt = deepcopy(t)
	for i = 1:cs
		if core
			for j = 1:cs
				if i !== j
					nt = ntuple(k->(k == dim ? j : Colon()), ndimensons)
					tt.core[nt...] .= 0
				end
			end
			Xe[i] = TensorDecompositions.compose(tt)
			tt.core .= t.core
		else
			for j = 1:cs
				if i !== j
					tt.factors[dim][:, j] .= 0
				end
			end
			Xe[i] = TensorDecompositions.compose(tt)
			tt.factors[dim] .= t.factors[dim]
		end
	end
	m = maximum.(Xe)
	imax = sortperm(m; rev=true)
	return Xe[imax[1:crank]]
end

function getgridvalues(v::Vector, d::Integer)
	l = length(v)
	Interpolations.interpolate((1:l,), v, Interpolations.Gridded(Interpolations.Linear()))[1:l/(d+1):l]
end

function getgridvalues(v, r; logtransform=true)
	lv = length(v)
	lr = length(r)
	@assert lv == lr
	f = similar(v)
	for i=1:lv
		try
			if logtransform
				f[i] = Interpolations.interpolate((log10.(r[i]),), 1:length(r[i]), Interpolations.Gridded(Interpolations.Linear()))[log10.(v[i])]
			else
				f[i] = Interpolations.interpolate((r[i],), 1:length(r[i]), Interpolations.Gridded(Interpolations.Linear()))[v[i]]
			end
		catch
			if logtransform
				f[i] = Interpolations.interpolate((sort!(log10.(r[i])),), length(r[i]):-1:1, Interpolations.Gridded(Interpolations.Linear()))[log10.(v[i])]
			else
				f[i] = Interpolations.interpolate((sort!(r[i]),), length(r[i]):-1:1, Interpolations.Gridded(Interpolations.Linear()))[v[i]]
			end
		end
	end
	return f
end

function getinterpolatedtensor(t::TensorDecompositions.Tucker{T,N}, v; sp=[Interpolations.BSpline(Interpolations.Quadratic(Interpolations.Line())), Interpolations.OnCell()]) where {T,N}
	lv = length(v)
	f = Vector(lv)
	factors = []
	for i = 1:N
		push!(factors, t.factors[i])
	end
	for j = 1:lv
		if !isnan(v[j])
			cv = size(t.factors[j], 2)
			f = Array{T}(1,cv)
			for i = 1:cv
				f[1, i] = Interpolations.interpolate(t.factors[j][:, i], sp...)[v[j]]
			end
			factors[j] = f
		end
	end
	tn = TensorDecompositions.Tucker((factors...), t.core)
	return tn
end

function gettensorcomponentorder(t::TensorDecompositions.Tucker, dim::Integer=1; method::Symbol=:core, firstpeak::Bool=true, reverse=true, quiet=true)
	cs = size(t.core)[dim]
	!quiet && info("Core size: $(size(t.core))")
	csize = TensorToolbox.mrank(t.core)
	!quiet && info("Core mrank: $csize")
	ndimensons = length(csize)
	@assert dim >= 1 && dim <= ndimensons
	crank = cs
	if method == :factormagnitude
		fmin = vec(minimum(t.factors[dim], 1))
		fmax = vec(maximum(t.factors[dim], 1))
		@assert cs == length(fmax)
		fdx = fmax .- fmin
		for i = 1:cs
			if fmax[i] == 0
				warn("Maximum of component $i is equal to zero!")
			end
			if fdx[i] == 0
				warn("Component $i has zero variability!")
				crank -= 1
			end
		end
		if reverse
			ifdx = sortperm(fdx; rev=reverse)[1:crank]
		else
			ifdx = sortperm(fdx; rev=reverse)[crank:end]
		end
		!quiet && info("Factor magnitudes (max - min): $fdx")
		if firstpeak
			imax = map(i->indmax(t.factors[dim][:, ifdx[i]]), 1:crank)
			order = ifdx[sortperm(imax)]
		else
			order = ifdx
		end
	else
		maxXe = Vector{Float64}(cs)
		tt = deepcopy(t)
		for i = 1:cs
			if method == :core
				for j = 1:cs
					if i !== j
						nt = ntuple(k->(k == dim ? j : Colon()), ndimensons)
						tt.core[nt...] .= 0
					end
				end
				Te = TensorDecompositions.compose(tt)
				maxXe[i] = maximum(Te) - minimum(Te)
				tt.core .= t.core
			else
				for j = 1:cs
					if i !== j
						tt.factors[dim][:, j] .= 0
					end
				end
				Te = TensorDecompositions.compose(tt)
				maxXe[i] = maximum(Te) - minimum(Te)
				tt.factors[dim] .= t.factors[dim]
			end
		end
		!quiet && info("Max core magnitudes: $maxXe")
		imax = sortperm(maxXe; rev=reverse)
		order = imax[1:cs]
	end
	return order
end

function mrank(t::TensorDecompositions.Tucker)
   TensorToolbox.mrank(t.core)
end

function gettensorminmax(t::TensorDecompositions.Tucker, dim::Integer=1; method::Symbol=:core)
	cs = size(t.core)[dim]
	csize = TensorToolbox.mrank(t.core)
	ndimensons = length(csize)
	@assert dim >= 1 && dim <= ndimensons
	crank = csize[dim]
	if method == :factormagnitude
		fmin = vec(minimum(t.factors[dim], 1))
		fmax = vec(maximum(t.factors[dim], 1))
		@assert cs == length(fmax)
		for i = 1:cs
			if fmax[i] == 0
				warn("Maximum of component $i is equal to zero!")
			end
		end
		info("Max factor magnitudes: $fmax")
		info("Min factor magnitudes: $fmin")
	elseif method == :all
		Te = TensorDecompositions.compose(t)
		tsize = size(Te)
		ts = tsize[dim]
		maxTe = Vector{Float64}(ts)
		minTe = Vector{Float64}(ts)
		for i = 1:tsize[dim]
			nt = ntuple(k->(k == dim ? i : Colon()), ndimensons)
			minTe[i] = minimum(Te[nt...])
			maxTe[i] = maximum(Te[nt...])
		end
		info("Max all magnitudes: $maxTe")
		info("Min all magnitudes: $minTe")
	else
		maxXe = Vector{Float64}(cs)
		minXe = Vector{Float64}(cs)
		tt = deepcopy(t)
		for i = 1:cs
			if method == :core
				for j = 1:cs
					if i !== j
						nt = ntuple(k->(k == dim ? j : Colon()), ndimensons)
						tt.core[nt...] .= 0
					end
				end
				Te = TensorDecompositions.compose(tt)
				minXe[i] = minimum(Te)
				maxXe[i] = maximum(Te)
				tt.core .= t.core
			else
				for j = 1:cs
					if i !== j
						tt.factors[dim][:, j] .= 0
					end
				end
				Te = TensorDecompositions.compose(tt)
				minXe[i] = minimum(Te)
				maxXe[i] = maximum(Te)
				tt.factors[dim] .= t.factors[dim]
			end
		end
		info("Max core magnitudes: $maxXe")
		info("Min core magnitudes: $minXe")
	end
end

function gettensorcomponentgroups(t::TensorDecompositions.Tucker, dim::Integer=1; cutvalue::Number=0.9)
	g = zeros(t.factors[dim][:, 1])
	v = maximum(t.factors[dim], 1) .> cutvalue
	gi = 0
	for i = 1:length(v)
		if v[i]
			m = t.factors[dim][:, i] .> cutvalue
			gi += 1
			g[m] = gi
		end
	end
	info("Number of component groups in dimension $dim is $(gi)")
	return g
end

function gettensormaximums(t::TensorDecompositions.Tucker{T,N}) where {T,N}
	for i=1:N
		v = maximum(t.factors[i], 1)
		if length(v) > 10
			vv = "[$(v[1]), $(v[2]), $(v[3]), ..., $(v[end])]"
		else
			vv = v
		end
		info("D$i factor: $(vv) Max: $(maximum(v))")
	end
	for i=1:N
		dp = Vector{Int64}(0)
		for j = 1:N
			if j != i
				push!(dp, j)
			end
		end
		v = vec(maximum(t.core, dp))
		if length(v) > 10
			vv = "[$(v[1]), $(v[2]), $(v[3]), ..., $(v[end])]"
		else
			vv = v
		end
		info("D$i core slice: $(vv) Max: $(maximum(v))")
	end
end

function recursivemkdir(s::String)
	d = Vector{String}()
	sc = deepcopy(s)
	while splitdir(sc)[1] != ""
		push!(d, splitdir(sc)[1])
		sc = splitdir(sc)[1]
	end
	for i = length(d):-1:1
		if isfile(d[i])
			warn("File $d[i] exists!")
		elseif !isdir(d[i])
			mkdir(d[i])
		end
	end
end

function recursivermdir(s::String)
	d = Vector{String}()
	sc = deepcopy(s)
	while splitdir(sc)[1] != ""
		push!(d, splitdir(sc)[1])
		sc = splitdir(sc)[1]
	end
	for i = 1:length(d)
		if isdir(d[i])
			rm(d[i]; force=true, recursive=true)
		end
	end
end

function nanmask(X::Array, mask, dim)
	if mask != nothing
		if length(size(mask)) == length(size(X))
			X[mask] .= NaN
		else
			X[remask(mask, size(X, dim))] .= NaN
		end
	end
	return nothing
end

function nanmask(X::Array, mask)
	if mask != nothing
		msize = vec(collect(size(mask)))
		xsize = vec(collect(size(X)))
		if length(msize) == length(xsize)
			X[mask] .= NaN
		else
			X[remask(mask, xsize[3:end])] .= NaN
		end
	end
	return nothing
end

function remask(sm, repeats::Integer=1)
	return reshape(repmat(sm, 1, repeats), (size(sm)..., repeats))
end

function remask(sm, repeats::Tuple)
	return reshape(repmat(sm, 1, *(repeats...)), (size(sm)..., repeats...))
end

function remask(sm, repeats::Vector{Int64})
	return reshape(repmat(sm, 1, *(repeats...)), (size(sm)..., repeats...))
end

function mapsize(csize)
	c = length(csize)
	s = ""
	for i = 1:c
		if i == c
			s *= "$(csize[i])"
		else
			s *= "$(csize[i])_"
		end
	end
	return s
end

