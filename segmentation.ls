{map, filter, maximumBy, unique, zipAll} = require 'prelude-ls'
require! './fobj.ls'
vm = require './vmath.ls'
{div, mul, sqrt, sub, add, pow, sum, cmap} = vm

export VelocityThreshold = fobj (@threshold=10) ->
	(ts, xs) ->
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


_NaiveOlpHypothesis = (noiseStd) ->
	nDim = noiseStd.length
	nParam = 2
	normer = div 1.0, (mul noiseStd, sqrt(2*Math.PI))
	normer = map Math.log, normer
	rnormer = (mul 2, (pow noiseStd, 2))

	class Hypothesis
		(@parent) ->
			if @parent?
				@pastLikelihood = @parent.likelihood! + @splitLikelihood!
			else
				@pastLikelihood = 0

			@fit = new vm.LinearFit

		measurement: (t, x) ->
			@start ?= t
			@fit.inc t, x
			@myLikelihood = @fitLikelihood @fit

		likelihood: ->
			denan @pastLikelihood + @myLikelihood

		minSurvivableLik: ->
			denan @likelihood! + @splitLikelihood!

		fitLikelihood: (f) ->
			if f.n < nParam
				return void
			residualSs = f.residualSs!
			# With vector-supporting operators and functions this would read
			# sum(h.n*log(1.0/noiseStd*sqrt(2*pi)) - residualSs/(2*noiseStd**2))
			normedResid = div residualSs, rnormer
			likelihoods = sub (mul f.n, normer), normedResid
			return sum likelihoods

		# Akaikish information criterion.
		# TODO: Figure out more principled stuff here
		splitLikelihood: ->
			-2*nParam*nDim

export NaiveOlp = (...args) -> new _NaiveOlp ...args
class _NaiveOlp
	(noiseStd) ->
		@Hypothesis = _NaiveOlpHypothesis noiseStd
		@hypotheses = [new @Hypothesis]
		@_data = ts: [], xs: []

	measurement: (t, x) ->
		@_data.ts.push t
		@_data.xs.push x
		candidates = filter (.likelihood!?), @hypotheses
		leader = maximumBy (.likelihood!), candidates
		if leader?
			pruneLimit = leader.minSurvivableLik!
			@hypotheses = filter ((h) -> not (h.likelihood! <= pruneLimit)), @hypotheses
			@hypotheses.push new @Hypothesis leader

		for h in @hypotheses
			h.measurement t, x

	fit: (ts, xs) ->
		for i from 0 til ts.length
			@measurement ts[i], xs[i]
		return @reconstruct!

	splits: ->
		h = maximumBy (.likelihood!), @hypotheses
		splits = []
		while h? and h.start?
			splits.unshift h.start
			h = h.parent
		return splits

	reconstruct: ->
		NaivePiecewiseLinearFit @splits!, @_data.ts, @_data.xs


export GreedyOlp = fobj (noiseStd) ->
	nDim = noiseStd.length

	# TODO: These need tweaking
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

	data = []

	p = @

	class Hypothesis
		(@parent, t0, x0) ->
			if parent?
				@pastLikelihood = @parent.likelihood! + splitLikelihood!
				@fit = new vm.SlopeFit t0: t0, x0: x0
			else
				@pastLikelihood = 0
				@fit = new vm.LinearFit

			@_prevT = void

		measurement: (t, x) ->
			@start ?= t
			@_prevT = t
			@fit.inc t, x
			@myLikelihood = fitLikelihood @fit

		likelihood: ->
			denan @pastLikelihood + @myLikelihood

		minSurvivableLik: ->
			denan @likelihood! + splitLikelihood!

		forks: ->
			mylik = @likelihood!
			return [] if not mylik?

			child = new Hypothesis @, @_prevT, @fit.predict @_prevT
			return [child]

	@hypotheses = [new Hypothesis]

	i = 0
	@measurement = (t, x) ->
		data.push [t, x]
		candidates = filter (.likelihood!?), @hypotheses
		leader = maximumBy (.likelihood!), candidates
		if leader?
			pruneLimit = leader.minSurvivableLik!
			@hypotheses = filter ((h) -> not (h.likelihood! <= pruneLimit)), @hypotheses
			@hypotheses ++= leader.forks!

		for h in @hypotheses
			h.measurement t, x
		i += 1

	@fit = (ts, xs) ->
		for [t, x] in zipAll ts, xs
			@measurement t, x
		return @reconstruct!

	@splits = ->
		h = maximumBy totalLikelihood, @hypotheses
		splits = []
		while h? and h.start?
			splits.unshift h.start
			h = h.parent
		return splits

	@reconstruct = fobj ->
		[ts, xs] = zipAll ...data
		GreedyPiecewiseLinearFit @splits!, ts, xs


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
		start = vm.searchAscendingFirst @ts, startT
		endT = @splits[endI]
		end = (vm.searchAscendingFirst (@ts.slice start), endT) + start
		return new vm.LinearFit ts: @ts.slice(start, end), xs: @xs.slice(start, end)

	@predictOne = (t) ->
		fit = subfit (vm.searchAscendingLast(@splits, t))
		return fit.predict(t)

	(ts) ~>
		cmap @~predictOne, ts

export GreedyPiecewiseLinearFit = fobj (@splits, @ts, @xs) ->
	subfit = memoize (endI) ~>
		if endI == 0
			return (-> NaN)

		endT = @splits[endI]
		end = (vm.searchAscendingFirst @ts, endT)
		if endI == 1
			return (new vm.LinearFit do
				ts: @ts.slice(0, end)
				xs: @xs.slice(0, end))~predict

		startT = @splits[endI - 1]
		start = vm.searchAscendingFirst @ts, startT

		prevFit = subfit endI - 1
		t0 = @ts[start - 1]
		x0 = prevFit t0
		(new vm.SlopeFit do
			ts: @ts.slice(start, end)
			xs: @xs.slice(start, end)
			t0: t0
			x0: x0)~predict

	@predictOne = (t) ->
		fit = subfit (vm.searchAscendingLast(@splits, t))
		return fit.predict(t)

	(ts) ~>
		cmap @~predictOne, ts
