{zipWith, fold, map, zipAll, findIndex, objsToLists} = require "prelude-ls"
require! './fobj.ls'

nj = require 'numeric'

export isScalar = (v) -> typeof v != 'object'

cwise = (f) -> (a, b) ->
	| isScalar a and isScalar b => f a, b
	| isScalar a => [f(a, ..) for b]
	| isScalar b => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]

cwiseUnary = (f) -> (xs) ->
	| isScalar xs => f xs
	| _ => [f x for x in xs]

export
	add = cwise (a, b) -> a + b
	sub = cwise (a, b) -> a - b
	mul = cwise (a, b) -> a * b
	div = cwise (a, b) -> a / b
	pow = cwise Math.pow
	sqrt = cwiseUnary Math.sqrt
	sum = (xs) ->
		return xs if isScalar xs
		total = 0
		for a in xs
			total += a
		return total
	norm = nj.norm2
	mean = (xs) -> (sum xs)/xs.length
	cmap = (f, v) -->
		| isScalar v => f v
		| _ => f `map` v

	getDim = (d) -> map (x) -> x[d]

	searchAscendingLast = (ts, t) -->
		# TODO: Could use binary or interpolation search
		(findIndex (> t), ts) ? ts.length

	searchAscendingFirst = (ts, t) -->
		# TODO: Could use binary or interpolation search
		(findIndex (>= t), ts) ? ts.length

	LinInterp = fobj (@ts, @xs) ->
		ts = @ts
		@interpOne = (t) ->
			return NaN if t < ts[0]
			return NaN if t > ts[*-1]
			i = (searchAscendingFirst ts, t) - 1
			return @xs[0] if i < 0

			dt = ts[i+1] - ts[i]
			w = (t - ts[i])/(ts[i+1] - ts[i])
			dx = (@xs[i+1] `sub` @xs[i]) `mul` w
			return @xs[i] `add` dx

		(ts) ->
			cmap @interpOne, ts

	class IncSs
		->
			@n = 0
			@m = 0.0
			@ss = 0.0

		inc: (x) ->
			@n += 1
			d = sub x, @m
			@m = add @m, (div d, @n)
			@ss = add @ss, (mul d, (sub x, @m))

	class SlopeFit
		({ts, xs, @t0=0.0, @x0=0.0}={}) ->
			@n = 0
			@Et = 0.0
			@Ett = 0.0
			@Exx = 0.0
			@Etx = 0.0
			if xs?
				for [t, x] in zipAll ts, xs
					@inc t, x

		inc: (t, x) ->
			@n += 1
			t = t - @t0
			x = sub x, @x0

			@Et += t
			@Ett += t*t
			@Exx = add @Exx, (mul x, x)
			@Etx = add @Etx, (mul t, x)


		residualSs: ->
			sub @Exx, (div (pow @Etx, 2), @Ett)

		slope: ->
			div @Etx, @Ett

		predict: (t) ->
			b = @slope!
			t = sub t, @t0
			return add @x0, (mul t, b)

	class LinearFit
		({ts, xs}={}) ->
			@t = new IncSs
			@x = new IncSs
			@n = 0.0
			@coSs = 0.0
			if xs?
				for [t, x] in zipAll ts, xs
					@inc t, x

		inc: (t, x) ->
			prevDt = t - @t.m
			@t.inc t
			@x.inc x
			@n = @t.n
			dx = sub x, @x.m
			@coSs = add @coSs, (mul prevDt, dx)

		residualSs: ->
			sub @x.ss, (div (pow @coSs, 2), @t.ss)

		coeffs: ->
			b = div @coSs, @t.ss
			a = sub @x.m, (mul b, @t.m)
			return [a, b]

		predict: (ts) ->
			[a, b] = @coeffs!
			if isScalar ts
				return add a, (mul b, ts)

			for t in ts
				add a, (mul b, t)

