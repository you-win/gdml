extends Reference

var css_parser = preload("./css_parser.gd").new()
var theme_applier = preload("./theme_applier.gd").new()
var css_simplifier = preload("./css_simplifier.gd").new()

# Each class is plit into a different theme
var output := {} # Theme name: String -> Theme

func _init() -> void:
	pass

func generate(text: String, stylesheet_name: String) -> void:
	# Ignore the folder
	var stylesheet = css_parser.parse_text(
		text, stylesheet_name if not stylesheet_name.empty() else "inline")

	if stylesheet == null:
		return
	
	var css_result = theme_applier.apply_css(css_simplifier.simplify(stylesheet))

	for key in css_result:
		if key.empty():
			output["default"] = css_result[key]
		else:
			output[key] = css_result[key]
