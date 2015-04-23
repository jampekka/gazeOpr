{zipWith, fold, map, zipAll, findIndex, objsToLists} = require "prelude-ls"
require! './fobj.ls'

nj = require 'numeric'

export isScalar = (v) -> typeof v != 'object'

cwiseTemplate = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]

refunc = (f) ->
	m = f.toString().match /(function\s?)([^\.])([\w|,|\s|-|_|\$]*)(.+?\{)([^\.][\s|\S]*(?=\}))/
	args = m[3].split ','
	body = m[5]
	return new Function args, body

#refunc cwiseTemplate

cwiseTemplate = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]

# TODO! Copypasting the stuff here because this brings
# about 3x speedup as V8 knows how to inline them
export cwise = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]

cwise1 = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]

cwise2 = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]


cwise3 = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]


cwise4 = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]

cwise5 = (f) -> (a, b) ->
	as = typeof a != 'object'
	bs = typeof b != 'object'
	switch
	| as and bs => f a, b
	| as => [f(a, ..) for b]
	| bs => [f(.., b) for a]
	| _ => [f(a[i], b[i]) for i from 0 til a.length]


export cwiseUnary = (f) -> (xs) ->
	| isScalar xs => f xs
	| _ => [f x for x in xs]

namef = (name, f) ->
	f.name = name
	return f

export
	add = cwise1 namef \add, (a, b) -> a + b
	sub = cwise2 namef \sub, (a, b) -> a - b
	mul = cwise3 namef \mul, (a, b) -> a * b
	div = cwise4 namef \div, (a, b) -> a / b
	pow = cwise5 Math.pow
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

		frozen: ->
			copy = @ with @
			copy.t = @t with @t
			copy.x = @x with @x
			return copy

	gaussianPdf1d = (std) ->
		normer = 1/(std*Math.sqrt(Math.PI*2))
		rnormer = 2*std*std
		(x) ->
			normer * Math.exp -(x*x)/rnormer

	gaussianKernel = (std, clipStds=3) ->
		ts = [-clipStds*std to clipStds*std]
		result = []
		total = 0
		pdf = gaussianPdf1d std
		for t in ts
			v = pdf t
			total += v
			result.push v

		for i from 0 til result.length
			result[i] /= total
		return result

	convolve1d = (signal, kernel) ->
		n = kernel.length
		mid = (n - 1)/2
		result = signal.slice()
		for i from 0 til signal.length
			result[i] = 0
			for offset from -mid to mid
				si = i + offset
				if (si < 0) or (si >= signal.length)
					si = i - offset

				result[i] += signal[si] * kernel[offset + mid]
		return result

	gaussianFilter1d = (noiseStd, ...opts) ->
		kernel = gaussianKernel noiseStd, ...opts
		if noiseStd == 0
			return (signal) -> signal.slice()
		(signal) ->
			convolve1d signal, kernel
/*
	cartesianProduct = (current, ...other) ->*
		if not current?
			yield []
			return
		for x in current
			o = cartesianProduct ...other
			``
			for(var sub of o) { yield [x].concat(sub); }
			``
		return

	gridSearch = (f, ...ranges) ->
		prod = cartesianProduct ...ranges
		until (v = prod.next!).done
			console.log v.value*/


