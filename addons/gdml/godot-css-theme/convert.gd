extends SceneTree


func _init():
	var options = GCT_Options.new()
	if not options.init():
		quit(1)
		return
	var debug = options.get_value("debug")

	var parser = GCT_CSSParser.new()
	var css_file = options.get_value("input")
	var stylesheet = parser.parse(css_file)
	if not stylesheet:
		quit(1)
		return

	var applier = GCT_ThemeApplier.new(debug)
	var simplifier = GCT_CSSSimplifier.new()
	var fullGCT_Stylesheet = simplifier.simplify(stylesheet)
	var themes = applier.apply_css(fullGCT_Stylesheet)

	var output = options.get_value("output")
	if not output:
		var last_slash = css_file.find_last("/")
		var file_name = css_file.substr(last_slash + 1)
		var dir_path = css_file.substr(0, last_slash)

		var file_name_without_ext = file_name.split(".")[0]
		output = dir_path + "/" + file_name_without_ext + ".tres"

	var output_dir = output.substr(0, output.find_last("/") + 1)
	print("Generating themes to %s" % output_dir)

	for theme_name in themes.keys():
		var theme = themes[theme_name]
		var theme_output = output_dir + theme_name + ".tres"
		if theme_name == "":
			theme_output = output
		
		var err = ResourceSaver.save(theme_output, theme)
		if err != OK:
			print("Failed to save theme %s" % err)
		else:
			print("Saved theme %s to %s" % [theme_name, theme_output])

	quit()
