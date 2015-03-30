{zipWith, fold, map} = require "prelude-ls"

# Probably polluting the namespace :(
require 'script!jStat/dist/jstat.js'

isScalar = (v) -> typeof v == 'number'

cwise = (f) --> (a, b) ->
	| isScalar a and isScalar b => f a, b
	| isScalar a => map f(a, _), b
	| isScalar b => map f(_, b), a
	| _ => zipWith f, a, b

add = cwise (+)
sub = cwise (-)
mul = cwise (*)
div = cwise (/)
pow = cwise (**)
sqrt = pow _, 0.5
sum = fold (+), 0, _
norm = (a) -> sqrt sum (pow a, 2)

fobj = (f) -> (...args) ->
	me = {}
	callable = f.apply(me, args) ? me
	# TODO: Could perhaps use proto here
	callable <<< me

export LinearPursuit = fobj (@x0, @x1, @speed) ->
	t = 0
	endtime = norm sub @x1, @x0
	(dt=0) ~>
		t += dt
		return x1 if t >= endtime
		reltime = t/endtime
		add mul(1-reltime, @x0), mul(reltime, @x1)

export RandomLinearPursuitSimulator = fobj ({
		@size=[20.0, 20.0], @meanDuration=0.250,
		@velocityDist=jStat.gamma(1.0, 10.0)
		}={}) ->
	# TODO: Could take a distribution instead of mean duration
	pos = [0.0, 0.0]
	@pursuitSpeed = @velocityDist~sample
	# Start from standstil
	@currentPursuit = LinearPursuit pos, pos, 0.0

	@newPursuit = (dt=0.0) ~>
		# TODO: Can change only "between samples". Although the effect is
		# probably negligible with the used sampling rates.
		rndpos = ~> map ((d) -> (Math.random() - 0.5) * d), @size
		src = rndpos!
		dst = rndpos!
		@currentPursuit = LinearPursuit src, dst, @pursuitSpeed!
		return @currentPursuit 0.0, true

	(dt) ~>
		# TODO: Can change only "between samples". Although the effect is
		# probably negligible with the used sampling rates.
		if Math.random() > Math.exp(-1/@meanDuration * dt)
			@newPursuit!

		return [@currentPursuit(dt), false]
