# GDML (Godot Markup Language)

[![Chat on Discord](https://img.shields.io/discord/853476898071117865?label=chat&logo=discord)](https://discord.gg/6mcdWWBkrr)

An HTML-inspired markup language for Godot UIs.

GDML parses an `xml` file and generates a corresponding tree of Godot `Node`s to be added to the `SceneTree`. Anonymous, inline scripts are allowed along with loading scripts from a context path.

## Quickstart

1. Copy the `./addons/gdml/` directory to your project's `addons` directory
2. Load `.addons/gdml/gdml.gd` and instance it. A context path (the directory containing the `xml` files + resources) must be provided
3. Call the `generate` method. A file name must be provided relative to the context path
   1. e.g. `var my_output: Control = gdml.generate("my_file.xml")`
4. Add the output to the `SceneTree`

## Example

1. Create a `CanvasLayer` on layer -1 and a black `ColorRect` to act as the background.
2. Creates a `gdml` container node that holds an anonymous script.
3. A `VBoxContainer` is created inside the `gdml` node that contains a `Label` and a `Button`.
4. The `Button` is hooked up to the anonymous script to print "hello" when the element is pressed.

```xml

<canvas_layer gdml_props="layer: -1">
    <color_rect gdml_name="Background" gdml_style="anchor: full_rect; color: (colorN) Black"/>
</canvas_layer>

<gdml gdml_style="anchor: full_rect; margin_top: 10; margin_left: 10">
    <gdml_script>
        func say_hello():
            print("hello")
    </gdml_script>

    <v_box_container gdml_style="anchor: full_rect">
        <label>Hello label!</label>
        <button pressed="say_hello">click me</button>
    </v_box_container>
</gdml>

```

## Design Decisions
* GDML-specific properties are prepended with `gdml_` in order to namespace them
* There is an implicit, global `gdml` node that wraps each `xml` file
  * This is needed since scripts can be placed at the root level
* `gdml_props` is an alias of `gdml_style` as they work in the same way (aka styles for Godot `Control`s are just properties)
* Context paths are used instead of `res://` paths, as the library is meant to be used for runtime loaded UIs. Because of this, context paths will generally point outside of the project

## 3rd Party Libraries
* [godot-css-theme](https://github.com/kuma-gee/godot-css-theme)
  * Modified to namespace the classes
