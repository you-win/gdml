extends Reference

var counter: int = 0

func give_test(i) -> String:
	counter += i
	return "%s_%d" % ["test", counter]
