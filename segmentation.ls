{map, filter, maximumBy, unique} = require 'prelude-ls'
require! './fobj.ls'
for name, val of require './vmath.ls' then eval "var #name = val"

export VelocityThreshold = fobj (@threshold=10) ->
	(ts, xs) ~>
		splits = []
		wasMoving = false
		for i in [1 til ts.length]
			t = ts[i]
			dt = t - ts[i - 1]
			dpos = norm xs[i] `sub` xs[i - 1]
			v = dpos/dt
			isMoving = v > @threshold
			if wasMoving != isMoving
				wasMoving = isMoving
				splits.push ts[i - 1]
		return splits

export Nols = fobj (noiseStd) ->
	nDim = noiseStd.length
	nParam = 2
	# Akaike information criterion.
	# TODO: Verify this is really Akaike and verify
	#	it converges to proper noise estimate
	splitLikelihood = ->
		-nParam*nDim

	fitLikelihood = (f) ->
		if f.n < nParam
			return void
		residualSs = f.residualSs!
		# With vector-supporting operators and functions this would read
		# sum(h.n*log(1.0/noiseStd*sqrt(2*pi)) - residualSs/(2*noiseStd**2))
		normer = div 1.0, (mul noiseStd, sqrt(2*Math.PI))
		normer = map Math.log, normer
		normedResid = div residualSs, (mul 2, (pow noiseStd, 2))
		likelihoods = sub (mul f.n, normer), normedResid
		return sum likelihoods

	totalLikelihood = (h) -> h.pastLikelihood + h.myLikelihood

	p = @


	Hypothesis = fobj (@parent) ->
		if @parent?
			@pastLikelihood = @parent.likelihood! + splitLikelihood!
		else
			@pastLikelihood = 0

		@fit = LinearFit!
		@measurement = (t, x) ~>
			@start ?= t
			@fit.inc t, x
			@myLikelihood = fitLikelihood @fit

		@likelihood = ~>
			@pastLikelihood + @myLikelihood

	@hypotheses = [Hypothesis!]

	i = 0
	@measurement = (t, x) ~>
		leader = maximumBy (.likelihood!), @hypotheses
		@hypotheses.push Hypothesis leader

		#pruneLimit = totalLikelihood newHypothesis
		#@hypotheses = filter ((h) -> totalLikelihood(h) > pruneLimit), @hypotheses

		for h in @hypotheses
			h.measurement t, x

		i += 1


	@splits = ~>
		h = maximumBy totalLikelihood, @hypotheses
		splits = []
		while h? and h.start?
			splits.unshift h.start
			h = h.parent
		return splits

#bruteNolp = (ts, gaze) ->

memoize = (f) ->
	cache = {}
	(x) ->
		if x not of cache
			cache[x] = f x
		return cache[x]

export PiecewiseLinearFit = fobj (@splits, @ts, @xs) ->
	@splits = unique @splits
	subfit = (endI) ~>
		# TODO: Something still amiss here!
		startT = @splits[endI - 1]
		start = searchAscendingFirst @ts, startT
		endT = @splits[endI]
		end = (searchAscendingFirst (@ts.slice start), endT) + start
		return LinearFit @ts.slice(start, end), @xs.slice(start, end)

	@predictOne = (t) ~>
		console.log "t", t
		fit = subfit (searchAscendingLast(@splits, t))
		return fit(t)

	(ts) ~>
		cmap @predictOne, ts
