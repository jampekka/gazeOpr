module.exports := (f) -> (...args) ->
	me = {}
	callable = f.apply(me, args)
	return me if not callable? or callable is me
	me.__proto__ = callable.__proto__
	callable.__proto__ = me
	return callable
