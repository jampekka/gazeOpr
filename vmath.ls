{zipWith, fold, map, zipAll, findIndex, objsToLists} = require "prelude-ls"
require! './fobj.ls'

export isScalar = (v) -> typeof v == 'number'

cwise = (f) --> (a, b) ->
	| isScalar a and isScalar b => f a, b
	| isScalar a => map f(a, _), b
	| isScalar b => map f(_, b), a
	| _ => zipWith f, a, b

export
	add = cwise (+)
	sub = cwise (-)
	mul = cwise (*)
	div = cwise (/)
	pow = cwise (**)
	sqrt = pow _, 0.5
	sum = fold (+), 0, _
	norm = (a) -> sqrt sum (pow a, 2)
	cmap = (f, v) -->
		| isScalar v => f v
		| _ => f `map` v

	getDim = (d) -> map (x) -> x[d]

	searchAscending = (ts, t) -->
		# TODO: Could use binary or interpolation search
		findIndex (>= t), ts

	LinInterp = fobj (@ts, @xs) ->
		ts = @ts
		@interpOne = (t) ~>
			return NaN if t < ts[0]
			return NaN if t > ts[*-1]
			i = (searchAscending ts, t) - 1
			return @xs[0] if i < 0

			dt = ts[i+1] - ts[i]
			w = (t - ts[i])/(ts[i+1] - ts[i])
			dx = (@xs[i+1] `sub` @xs[i]) `mul` w
			return @xs[i] `add` dx

		(ts) ~>
			cmap @interpOne, ts

	IncSs = fobj ->
		@n = 0
		@m = 0
		@ss = 0

		(x) ~>
			@n += 1
			@d = sub x, @m
			@m = add @m, (div @d, @n)
			@ss = add @ss, (mul @d, (sub x, @m))

	LinearFit = fobj (ts, xs) ->
		@t = IncSs!
		@x = IncSs!
		@n = 0
		coSs = 0

		@inc = (t, x) ~>
			@t t
			@x x
			@n = @t.n
			w = (@n - 1) / @n
			coSs := add coSs, (mul w, (mul @t.d, @x.d))

		@residualSs = ~>
			add @x.ss, (div (pow coSs, 2), @t.ss)

		@coeffs = ~>
			b = div coSs, @t.ss
			a = sub @x.m, (mul b, @t.m)
			return [a, b]

		if xs?
			for [t, x] in zipAll ts, xs
				@inc t, x

		(t) ~>
			[a, b] = @coeffs!
			return add a, (mul t, b)

