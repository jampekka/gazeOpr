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

export Reconstruct = fobj (@splitter, @ts, @gaze) ->
	# TODO: NO NO NO!
	@splits = (@splitter @ts, @gaze)
	splits = [@ts[0]] ++ @splits ++ [@ts[*-1]]
	LinInterp splits, (LinInterp(@ts, @gaze) splits)
