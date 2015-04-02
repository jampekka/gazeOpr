{zipWith, fold, map, zipAll, values, findIndex} = require "prelude-ls"
require! "./fobj.ls"
require "./vmath.ls"

# Probably polluting the namespace :(
require 'script!jStat/dist/jstat.js'
# Pollutes the global namespace :(
# TODO: Could use import/export loaders of webpack.
# TODO: Fili seems to export stuff, but doesn't seem
# to work with a simple require
require 'script!fili/dist/fili.js'
for name, val of require './vmath.ls' then eval "var #name = val"

export LinearPursuit = fobj (@x0, @x1, @speed) ->
	@t = 0
	@targetT = div (norm sub @x1, @x0), @speed
	dir = sub @x1, @x0
	@velocity = mul @speed, div dir, (norm dir)
	(dt=0) ~>
		@t += dt
		return @x1 if @t >= @targetT

		add @x0, (mul @velocity, @t)

DEFAULT_AREA_SIZE = [20, 20]

cumsum = (xs) ->
	total = 0
	map ((x) -> total += x), xs

RandomSampler = fobj (@weights, @values=[0 til @weights.length]) ->
	@cumweights = cumsum div @weights, sum @weights
	~>
		p = Math.random()
		i = findIndex (> p), @cumweights
		@values[i]

MixtureDistribution = fobj (@dists, @weights=[1]*@dists.length) ->
	totalWeight = sum @weights
	@weights = map (/totalWeight), @weights
	@randomDistribution = RandomSampler @weights, @dists

	wrap = (fname) ~> (...args) ~>
		raw = map ((d) -> d[fname] ...args), @dists
		sum mul raw, @weights

	@pdf = wrap \pdf
	@cdf = wrap \cdf

	@sample = ~>
		@randomDistribution! .sample!

NdDistribution = fobj (@dDists=[]) ->
	wrap = (fname) ~> (...args) ~>
		# TODO: Not very nice
		subargs = zipAll ...(args)
		for d, i in @dDists
			d[fname] ...subargs[i]

	@pdf = wrap \cdf
	@cdf = wrap \cdf
	@sample = wrap \sample

DeltaDistribution = fobj (@value) ->
	@pdf = (x) ~>
		| x == @value => Infinity
		| _ => 0

	@cdf = (x) ~>
		| x < @value => 0
		| _ => 1

	@sample = ~> @value

# TODO: Estimate the pursuits from literature
defaultSpeedDistribution = MixtureDistribution [
	jStat.gamma 4.0, 3.0 # "Smooth pursuits"
	DeltaDistribution Infinity # Jumps or "Saccades"
	]

# TODO: Estimate mean duration from literature
export RandomLinearMovementSimulator = fobj ({
		@size=DEFAULT_AREA_SIZE,
		@speedDist=defaultSpeedDistribution
		@meanDuration=0.5
		}={}) ->
	@pursuitSpeed = @speedDist~sample

	@newPursuit = (src) ~>
		# TODO: Can change only "between samples". Although the effect is
		# probably negligible with the used sampling rates.
		rndpos = ~> map ((d) -> (Math.random() - 0.5) * d), @size
		dst = rndpos!
		LinearPursuit src, dst, @pursuitSpeed!

	@currentPursuit = @newPursuit [0.0, 0.0]

	(dt) ~>
		pos = @currentPursuit(dt)
		if Math.random() > Math.exp(-1/@meanDuration * dt)
			@currentPursuit = @newPursuit pos
		return pos

# Default parametrization estimated from the values of
# Table 1 of "Variability and development of a normative
# data base for saccadic eye movements", Bahill et al 1989.
# TODO: ESTIMATE AGAIN FOR FILI!!!
export BesselEyeDynamics = ({dt,order=3,cutoff=11.0}) ->
	coeffs = (new CalcCascades) .lowpass do
		order: order
		characteristic: 'bessel'
		Fs: 1.0/dt
		Fc: cutoff
		gain: 0
		preGain: false
	filt = new IirFilter coeffs
	# TODO: Could do by-sample too
	(input) ->
		axes = zipAll ...input
		filtered = map filt~simulate, axes
		zipAll ...filtered

NdNormNoise = (noiseStds) ->
	NdDistribution ((s) -> jStat.normal(0, s)) `map` noiseStds

export SignalSimulator = fobj ({
	@dt=0.001, @duration=60.0,
	@target=RandomLinearMovementSimulator!
	@dynamics=BesselEyeDynamics dt: @dt
	@noise=NdNormNoise [0.5]*2
		}={}) ->
	p = @
	fobj (@duration=p.duration) ->
		@simulator = p
		@ts = [0 to @duration by p.dt]
		# TODO: Seems to go to infinite loop with empty ts
		@target = (-> p.target(p.dt)) `map` @ts
		@gaze = p.dynamics @target
		@measurement = ((x) -> add x, p.noise.sample!) `map` @gaze

