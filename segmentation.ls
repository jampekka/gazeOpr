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

denan = (v) ->
	| v == v => v
	| _ => void

export NaiveOls = fobj (noiseStd) ->
	nDim = noiseStd.length
	nParam = 2
	# Akaikish information criterion.
	# TODO: Figure out more principled stuff here
	splitLikelihood = ->
		-2*nParam*nDim

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
			denan @pastLikelihood + @myLikelihood

		@minSurvivableLik = ~>
			denan @likelihood! + splitLikelihood!

	@hypotheses = [Hypothesis!]

	i = 0
	@measurement = (t, x) ~>
		candidates = filter (.likelihood!?), @hypotheses
		leader = maximumBy (.likelihood!), candidates
		if leader?
			pruneLimit = leader.minSurvivableLik!
			@hypotheses = filter ((h) -> not (h.likelihood! < pruneLimit)), @hypotheses
			@hypotheses.push Hypothesis leader

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

export GreedyOls = fobj (noiseStd) ->
	nDim = noiseStd.length
	nParam = 2
	# Akaikish information criterion.
	# TODO: Figure out more principled stuff here
	splitLikelihood = ->
		-2*nParam*nDim

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

	Hypothesis = fobj (@parent, t0, x0) ->
		if @parent?
			@pastLikelihood = @parent.likelihood! + splitLikelihood!
			@fit = SlopeFit t0: t0, x0: x0
		else
			@pastLikelihood = 0
			@fit = LinearFit!

		prevT = void

		@measurement = (t, x) ~>
			@start ?= t
			prevT := t
			@fit.inc t, x
			@myLikelihood = fitLikelihood @fit

		@likelihood = ~>
			denan @pastLikelihood + @myLikelihood

		@minSurvivableLik = ~>
			denan @likelihood! + splitLikelihood!

		@forks = ~>
			mylik = @likelihood!
			return [] if not mylik?

			child = Hypothesis @, prevT, @fit prevT
			return [child]

	@hypotheses = [Hypothesis!]

	i = 0
	@measurement = (t, x) ~>
		candidates = filter (.likelihood!?), @hypotheses
		leader = maximumBy (.likelihood!), candidates
		if leader?
			pruneLimit = leader.minSurvivableLik!
			@hypotheses = filter ((h) -> not (h.likelihood! < pruneLimit)), @hypotheses
			@hypotheses ++= leader.forks!

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

export NaivePiecewiseLinearFit = fobj (@splits, @ts, @xs) ->
	subfit = memoize (endI) ~>
		startT = @splits[endI - 1]
		start = searchAscendingFirst @ts, startT
		endT = @splits[endI]
		end = (searchAscendingFirst (@ts.slice start), endT) + start
		return LinearFit @ts.slice(start, end), @xs.slice(start, end)

	@predictOne = (t) ~>
		fit = subfit (searchAscendingLast(@splits, t))
		return fit(t)

	(ts) ~>
		cmap @predictOne, ts

export GreedyPiecewiseLinearFit = fobj (@splits, @ts, @xs) ->
	subfit = (endI) ~>
		if endI == 0
			return (-> NaN)

		endT = @splits[endI]
		end = (searchAscendingFirst @ts, endT)
		if endI == 1
			return LinearFit do
				ts: @ts.slice(0, end)
				xs: @xs.slice(0, end)

		startT = @splits[endI - 1]
		start = searchAscendingFirst @ts, startT

		prevFit = subfit endI - 1
		t0 = @ts[start - 1]
		x0 = prevFit t0
		SlopeFit do
			ts: @ts.slice(start, end)
			xs: @xs.slice(start, end)
			t0: t0
			x0: x0

	@predictOne = (t) ~>
		fit = subfit (searchAscendingLast(@splits, t))
		return fit(t)

	(ts) ~>
		cmap @predictOne, ts
