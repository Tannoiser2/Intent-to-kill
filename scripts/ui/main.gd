extends Control
## Radice dell'applicazione: alterna menu, partita e regole.

var current: Control
var net: Net


func get_net() -> Net:
	if net == null:
		net = Net.new()
		add_child(net)
	return net


func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	# notte di pioggia: buio, una luce di lampione e la grana della pellicola
	sh.code = """shader_type canvas_item;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 uv = UV * vec2(1.78, 1.0);
	vec3 c = mix(vec3(0.035, 0.032, 0.036), vec3(0.075, 0.06, 0.055), smoothstep(1.1, 0.0, length(uv - vec2(1.25, 0.15))));
	c += vec3(0.20, 0.13, 0.06) * smoothstep(0.65, 0.0, length(uv - vec2(1.25, 0.12))) * 0.35;
	float t = TIME * 1.6;
	vec2 q = vec2(uv.x * 90.0 + uv.y * 9.0, uv.y * 7.0 + t);
	float pioggia = step(0.985, h(floor(q))) * smoothstep(0.0, 1.0, fract(q.y));
	c += vec3(0.25, 0.27, 0.3) * pioggia * 0.25;
	c += (h(UV * 900.0 + fract(TIME) * 37.0) - 0.5) * 0.035;
	c *= 1.0 - 0.55 * pow(length(UV - vec2(0.5)), 2.0);
	COLOR = vec4(c, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	fondo.material = mat
	add_child(fondo)
	show_menu()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _clear() -> void:
	if current != null:
		current.queue_free()
		current = null


func show_menu() -> void:
	_clear()
	var m := preload("res://scripts/ui/menu.gd").new()
	m.main = self
	add_child(m)
	current = m


func start_game(config: Dictionary) -> void:
	_clear()
	var g := preload("res://scripts/ui/partita.gd").new()
	g.main = self
	g.config = config
	add_child(g)
	current = g


func show_rules() -> void:
	_clear()
	var t := preload("res://scripts/ui/regole.gd").new()
	t.main = self
	add_child(t)
	current = t
