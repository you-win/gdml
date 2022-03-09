class_name GCT_Options

var _options = {
	input = ['', 'CSS Input File'],
	output = ['', 'Theme Output File'],
	config_file = ['res://.godot-css-config.json', 'Config file'],
	debug = [false, 'Enable debug mode']
}

var args: GCT_ArgumentParser

func init() -> bool:
	args = GCT_ArgumentParser.new()
	args.setup('Godot CSS to Theme converter', _options)
	return args.parse()

func get_value(key: String) -> String:
	if not args: return ""
	return args.get_value(key)
