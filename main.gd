extends Node2D

var graph_rect: Rect2 = Rect2(25.0, 65.0, 620.0, 520.0)
var view_min: Vector2 = Vector2(-1.0, -1.0)
var view_max: Vector2 = Vector2(1.0, 1.0)
var graph_scale: float = 1.0

var start_position_m: Vector2 = Vector2(0.0, 10.0)
var velocity_mps: Vector2 = Vector2(12.0, 0.0)
var initial_velocity_mps: Vector2 = Vector2.ZERO
var mass_kg: float = 1.0
var material_density_kg_m3: float = 2700.0
var frontal_area_m2: float = 0.01
var drag_coefficient: float = 0.47
var shape_name: String = "Sphere"

var planet_name: String = "Earth"
var surface_gravity_mps2: float = 9.82
var planet_radius_m: float = 6378000.0
var sea_level_air_density_kg_m3: float = 1.217
var atmosphere_scale_height_m: float = 8500.0
var vacuum_mode: bool = false

var running: bool = false
var paused: bool = false
var simulation_finished: bool = false
var result_recorded: bool = false
var run_count: int = 0

var elapsed_time_s: float = 0.0
var maximum_height_m: float = 0.0
var landing_x_m: float = 0.0
var impact_speed_mps: float = 0.0
var path: PackedVector2Array = PackedVector2Array()

var hud_panel: PanelContainer
var pause_button: Button
var speed_menu: OptionButton
var results_table: Tree
var results_root: TreeItem
var preset_menu: OptionButton


func _ready() -> void:
	create_interface()
	update_layout()
	queue_redraw()


func update_layout() -> void:
	var window_size: Vector2 = get_viewport_rect().size

	if hud_panel != null:
		hud_panel.position = Vector2(window_size.x - hud_panel.size.x - 15.0, 15.0)

	graph_rect = Rect2(
		25.0,
		65.0,
		maxf(180.0, window_size.x - 505.0),
		maxf(250.0, window_size.y - 110.0)
	)


func create_interface() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	canvas.layer = 10
	add_child(canvas)

	hud_panel = PanelContainer.new()
	hud_panel.name = "HUD"
	hud_panel.size = Vector2(460.0, 600.0)
	canvas.add_child(hud_panel)

	var tabs: TabContainer = TabContainer.new()
	tabs.name = "Tabs"
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_panel.add_child(tabs)

	create_launch_tab(tabs)
	create_rock_tab(tabs)
	create_environment_tab(tabs)
	create_results_tab(tabs)


func create_launch_tab(tabs: TabContainer) -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Launch"
	tabs.add_child(tab)

	add_heading(tab, "Launch parameters")
	add_number(tab, "StartX", "Starting X location (m)", "0")
	add_number(tab, "StartY", "Starting height (m)", "10")
	add_number(tab, "VelocityX", "Initial X velocity (m/s)", "12")
	add_number(tab, "VelocityY", "Initial Y velocity (m/s)", "0")
	add_number(tab, "Mass", "Mass (kg)", "1")

	var start_button: Button = Button.new()
	start_button.text = "Start simulation"
	start_button.pressed.connect(start_simulation)
	tab.add_child(start_button)

	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(toggle_pause)
	tab.add_child(pause_button)

	var speed_label: Label = Label.new()
	speed_label.text = "Simulation speed"
	tab.add_child(speed_label)

	speed_menu = OptionButton.new()
	speed_menu.add_item("0.25×")
	speed_menu.add_item("1×")
	speed_menu.add_item("5×")
	speed_menu.select(1)
	tab.add_child(speed_menu)


func create_rock_tab(tabs: TabContainer) -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Rock"
	tabs.add_child(tab)

	add_heading(tab, "Rock properties")
	add_number(tab, "Density", "Material density (kg/m³)", "2700")

	var shape_label: Label = Label.new()
	shape_label.text = "Shape assumption"
	tab.add_child(shape_label)

	var shape_menu: OptionButton = OptionButton.new()
	shape_menu.name = "Shape"
	shape_menu.add_item("Sphere")
	shape_menu.add_item("Cube")
	shape_menu.add_item("Flat plate")
	tab.add_child(shape_menu)

	add_number(tab, "Area", "Area override (m², 0 = automatic)", "0")
	add_number(tab, "Cd", "Drag coefficient override (0 = default)", "0")


func create_environment_tab(tabs: TabContainer) -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Environment"
	tabs.add_child(tab)

	add_heading(tab, "Planet and atmosphere")

	var preset_label: Label = Label.new()
	preset_label.text = "Planet preset"
	tab.add_child(preset_label)

	preset_menu = OptionButton.new()
	preset_menu.name = "PlanetPreset"

	preset_menu.add_item("Mercury")
	preset_menu.add_item("Venus")
	preset_menu.add_item("Earth")
	preset_menu.add_item("Mars")
	preset_menu.add_item("Jupiter")
	preset_menu.add_item("Saturn")
	preset_menu.add_item("Uranus")
	preset_menu.add_item("Neptune")

	preset_menu.select(2)
	preset_menu.item_selected.connect(apply_planet_preset)
	tab.add_child(preset_menu)

	add_number(tab, "Gravity", "Surface gravity (m/s²)", "9.82")
	add_number(tab, "PlanetRadius", "Reference radius (m)", "6378000")
	add_number(tab, "AirDensity", "Reference air density (kg/m³)", "1.217")
	add_number(tab, "ScaleHeight", "Atmosphere scale height (m)", "8500")

	var vacuum_check: CheckButton = CheckButton.new()
	vacuum_check.name = "Vacuum"
	vacuum_check.text = "Vacuum mode: no air resistance"
	tab.add_child(vacuum_check)

	var note: Label = Label.new()
	note.text = "Gas-giant values use a reference pressure level, not solid ground."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(note)


func create_results_tab(tabs: TabContainer) -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Results"
	tabs.add_child(tab)

	add_heading(tab, "Results history")

	results_table = Tree.new()
	results_table.columns = 11
	results_table.column_titles_visible = true
	results_table.size_flags_vertical = Control.SIZE_EXPAND_FILL

	results_table.set_column_title(0, "Run")
	results_table.set_column_title(1, "Planet")
	results_table.set_column_title(2, "Mass")
	results_table.set_column_title(3, "Height")
	results_table.set_column_title(4, "Vx")
	results_table.set_column_title(5, "Vy")
	results_table.set_column_title(6, "Shape")
	results_table.set_column_title(7, "Time")
	results_table.set_column_title(8, "Landing X")
	results_table.set_column_title(9, "Max H")
	results_table.set_column_title(10, "Impact")

	for column in range(11):
		results_table.set_column_expand(column, false)
		results_table.set_column_custom_minimum_width(column, 72)

	results_table.set_column_custom_minimum_width(1, 85)
	results_table.set_column_custom_minimum_width(6, 85)

	results_root = results_table.create_item()
	tab.add_child(results_table)

	var clear_button: Button = Button.new()
	clear_button.text = "Clear results history"
	clear_button.pressed.connect(clear_results)
	tab.add_child(clear_button)


func add_heading(box: VBoxContainer, text: String) -> void:
	var heading: Label = Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 18)
	box.add_child(heading)


func add_number(box: VBoxContainer, field_name: String, label_text: String, default_value: String) -> void:
	var label: Label = Label.new()
	label.text = label_text
	box.add_child(label)

	var input: LineEdit = LineEdit.new()
	input.name = field_name
	input.text = default_value
	box.add_child(input)


func apply_planet_preset(index: int) -> void:
	var gravity: float = 9.82
	var radius: float = 6378000.0
	var density: float = 1.217
	var scale_height: float = 8500.0
	var vacuum: bool = false

	match index:
		0:
			gravity = 3.70
			radius = 2439400.0
			density = 0.0
			scale_height = 1.0
			vacuum = true
		1:
			gravity = 8.87
			radius = 6051800.0
			density = 65.0
			scale_height = 15500.0
		2:
			gravity = 9.82
			radius = 6378000.0
			density = 1.217
			scale_height = 8500.0
		3:
			gravity = 3.71
			radius = 3396200.0
			density = 0.0156
			scale_height = 11100.0
		4:
			gravity = 23.12
			radius = 71492000.0
			density = 0.16
			scale_height = 27000.0
		5:
			gravity = 9.01
			radius = 60268000.0
			density = 0.19
			scale_height = 59500.0
		6:
			gravity = 9.01
			radius = 25600000.0
			density = 0.42
			scale_height = 27700.0
		7:
			gravity = 11.15
			radius = 24764000.0
			density = 0.45
			scale_height = 19000.0

	set_number("Environment", "Gravity", gravity)
	set_number("Environment", "PlanetRadius", radius)
	set_number("Environment", "AirDensity", density)
	set_number("Environment", "ScaleHeight", scale_height)
	set_check("Vacuum", vacuum)


func start_simulation() -> void:
	read_parameters_from_interface()

	elapsed_time_s = 0.0
	maximum_height_m = start_position_m.y
	landing_x_m = 0.0
	impact_speed_mps = 0.0
	initial_velocity_mps = velocity_mps

	path.clear()
	path.append(start_position_m)

	running = true
	paused = false
	simulation_finished = false
	result_recorded = false
	pause_button.text = "Pause"

	queue_redraw()


func read_parameters_from_interface() -> void:
	start_position_m = Vector2(
		get_number("Launch", "StartX"),
		get_number("Launch", "StartY")
	)

	velocity_mps = Vector2(
		get_number("Launch", "VelocityX"),
		get_number("Launch", "VelocityY")
	)

	mass_kg = maxf(get_number("Launch", "Mass"), 0.001)
	material_density_kg_m3 = maxf(get_number("Rock", "Density"), 1.0)

	surface_gravity_mps2 = maxf(get_number("Environment", "Gravity"), 0.01)
	planet_radius_m = maxf(get_number("Environment", "PlanetRadius"), 1.0)
	sea_level_air_density_kg_m3 = maxf(get_number("Environment", "AirDensity"), 0.0)
	atmosphere_scale_height_m = maxf(get_number("Environment", "ScaleHeight"), 1.0)
	vacuum_mode = get_check("Vacuum")

	planet_name = preset_menu.get_item_text(preset_menu.selected)
	shape_name = get_shape_name()

	calculate_rock_geometry()


func calculate_rock_geometry() -> void:
	var volume_m3: float = mass_kg / material_density_kg_m3
	var automatic_area_m2: float = 0.01
	var automatic_cd: float = 0.47

	if shape_name == "Sphere":
		var radius_m: float = float(pow((3.0 * volume_m3) / (4.0 * PI), 1.0 / 3.0))
		automatic_area_m2 = PI * radius_m * radius_m
		automatic_cd = 0.47

	elif shape_name == "Cube":
		var side_m: float = float(pow(volume_m3, 1.0 / 3.0))
		automatic_area_m2 = side_m * side_m
		automatic_cd = 1.05

	else:
		automatic_area_m2 = float(pow(volume_m3, 2.0 / 3.0)) * 6.0
		automatic_cd = 1.28

	var area_override_m2: float = get_number("Rock", "Area")
	var cd_override: float = get_number("Rock", "Cd")

	frontal_area_m2 = automatic_area_m2 if area_override_m2 <= 0.0 else area_override_m2
	drag_coefficient = automatic_cd if cd_override <= 0.0 else cd_override


func get_number(tab_name: String, field_name: String) -> float:
	var node: Node = get_node("CanvasLayer/HUD/Tabs/" + tab_name + "/" + field_name)
	var input: LineEdit = node as LineEdit
	return input.text.to_float()


func set_number(tab_name: String, field_name: String, value: float) -> void:
	var node: Node = get_node("CanvasLayer/HUD/Tabs/" + tab_name + "/" + field_name)
	var input: LineEdit = node as LineEdit
	input.text = str(value)


func get_check(field_name: String) -> bool:
	var node: Node = get_node("CanvasLayer/HUD/Tabs/Environment/" + field_name)
	var check: CheckButton = node as CheckButton
	return check.button_pressed


func set_check(field_name: String, value: bool) -> void:
	var node: Node = get_node("CanvasLayer/HUD/Tabs/Environment/" + field_name)
	var check: CheckButton = node as CheckButton
	check.button_pressed = value


func get_shape_name() -> String:
	var node: Node = get_node("CanvasLayer/HUD/Tabs/Rock/Shape")
	var shape_menu: OptionButton = node as OptionButton
	return shape_menu.get_item_text(shape_menu.selected)


func toggle_pause() -> void:
	if not running:
		return

	paused = not paused
	pause_button.text = "Resume" if paused else "Pause"


func get_speed_multiplier() -> float:
	if speed_menu.selected == 0:
		return 0.25
	if speed_menu.selected == 2:
		return 5.0
	return 1.0


func gravity_at_height(height_m: float) -> float:
	var altitude_m: float = maxf(height_m, 0.0)
	return surface_gravity_mps2 * float(pow(planet_radius_m / (planet_radius_m + altitude_m), 2.0))


func air_density_at_height(height_m: float) -> float:
	if vacuum_mode:
		return 0.0

	var altitude_m: float = maxf(height_m, 0.0)
	return sea_level_air_density_kg_m3 * float(exp(-altitude_m / atmosphere_scale_height_m))


func _physics_process(delta: float) -> void:
	if not running or paused:
		return

	var simulation_delta: float = delta * get_speed_multiplier()
	var steps: int = maxi(1, int(ceil(simulation_delta / 0.01)))
	var step_delta: float = simulation_delta / float(steps)

	for step in range(steps):
		update_simulation(step_delta)

		if simulation_finished:
			break

	queue_redraw()


func update_simulation(delta: float) -> void:
	var old_position: Vector2 = start_position_m
	var old_velocity: Vector2 = velocity_mps

	var gravity_force: Vector2 = Vector2(0.0, -mass_kg * gravity_at_height(start_position_m.y))
	var speed_mps: float = velocity_mps.length()
	var current_air_density: float = air_density_at_height(start_position_m.y)

	var drag_force: Vector2 = -0.5 * current_air_density * drag_coefficient * frontal_area_m2 * speed_mps * velocity_mps
	var acceleration_mps2: Vector2 = (gravity_force + drag_force) / mass_kg

	velocity_mps += acceleration_mps2 * delta
	start_position_m += velocity_mps * delta

	elapsed_time_s += delta
	maximum_height_m = maxf(maximum_height_m, start_position_m.y)

	if start_position_m.y <= 0.0:
		var denominator: float = old_position.y - start_position_m.y
		var hit_fraction: float = old_position.y / denominator

		start_position_m = old_position.lerp(start_position_m, hit_fraction)
		velocity_mps = old_velocity.lerp(velocity_mps, hit_fraction)
		elapsed_time_s -= delta * (1.0 - hit_fraction)

		landing_x_m = start_position_m.x
		impact_speed_mps = velocity_mps.length()

		running = false
		simulation_finished = true

		if not result_recorded:
			add_result_to_history()
			result_recorded = true

	path.append(start_position_m)


func add_result_to_history() -> void:
	run_count += 1

	var row: TreeItem = results_table.create_item(results_root)

	row.set_text(0, str(run_count))
	row.set_text(1, planet_name)
	row.set_text(2, "%.2f kg" % mass_kg)
	row.set_text(3, "%.1f m" % path[0].y)
	row.set_text(4, "%.1f" % initial_velocity_mps.x)
	row.set_text(5, "%.1f" % initial_velocity_mps.y)
	row.set_text(6, shape_name)
	row.set_text(7, "%.2f s" % elapsed_time_s)
	row.set_text(8, "%.2f m" % landing_x_m)
	row.set_text(9, "%.2f m" % maximum_height_m)
	row.set_text(10, "%.2f m/s" % impact_speed_mps)


func clear_results() -> void:
	run_count = 0
	results_table.clear()
	results_root = results_table.create_item()


func update_graph_view() -> void:
	var minimum: Vector2 = Vector2(0.0, 0.0)
	var maximum: Vector2 = Vector2(1.0, 1.0)

	for point in path:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)

	var width_m: float = maxf(maximum.x - minimum.x, 1.0)
	var height_m: float = maxf(maximum.y - minimum.y, 1.0)

	minimum.x -= width_m * 0.12
	maximum.x += width_m * 0.12
	minimum.y -= height_m * 0.12
	maximum.y += height_m * 0.12

	view_min = minimum
	view_max = maximum

	var scale_x: float = graph_rect.size.x / (view_max.x - view_min.x)
	var scale_y: float = graph_rect.size.y / (view_max.y - view_min.y)
	graph_scale = minf(scale_x, scale_y)


func to_screen_position(world_position: Vector2) -> Vector2:
	return Vector2(
		graph_rect.position.x + (world_position.x - view_min.x) * graph_scale,
		graph_rect.end.y - (world_position.y - view_min.y) * graph_scale
	)


func _draw() -> void:
	update_layout()
	update_graph_view()

	var font: Font = ThemeDB.fallback_font

	draw_rect(graph_rect, Color(0.05, 0.05, 0.08), true)
	draw_rect(graph_rect, Color.WHITE, false, 2.0)

	for i in range(9):
		var x_value: float = view_min.x + ((view_max.x - view_min.x) / 8.0) * float(i)
		var x_screen: float = to_screen_position(Vector2(x_value, 0.0)).x

		draw_line(Vector2(x_screen, graph_rect.position.y), Vector2(x_screen, graph_rect.end.y), Color.DIM_GRAY, 1.0)
		draw_string(font, Vector2(x_screen + 2.0, graph_rect.end.y + 20.0), "%.1f" % x_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)

		var y_value: float = view_min.y + ((view_max.y - view_min.y) / 8.0) * float(i)
		var y_screen: float = to_screen_position(Vector2(0.0, y_value)).y

		draw_line(Vector2(graph_rect.position.x, y_screen), Vector2(graph_rect.end.x, y_screen), Color.DIM_GRAY, 1.0)
		draw_string(font, Vector2(graph_rect.position.x + 4.0, y_screen - 3.0), "%.1f" % y_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)

	var origin: Vector2 = to_screen_position(Vector2.ZERO)
	draw_line(Vector2(graph_rect.position.x, origin.y), Vector2(graph_rect.end.x, origin.y), Color.WHITE, 2.0)
	draw_line(Vector2(origin.x, graph_rect.position.y), Vector2(origin.x, graph_rect.end.y), Color.WHITE, 2.0)

	draw_string(font, Vector2(graph_rect.end.x - 45.0, graph_rect.end.y + 42.0), "x (m)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
	draw_string(font, Vector2(graph_rect.position.x + 5.0, graph_rect.position.y + 20.0), "height (m)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)

	var status: String = "Time: %.2f s" % elapsed_time_s

	if paused:
		status += "   PAUSED"
	elif simulation_finished:
		status += "   IMPACT"

	draw_string(font, Vector2(graph_rect.end.x - 200.0, 35.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color.WHITE)

	for i in range(1, path.size()):
		draw_line(to_screen_position(path[i - 1]), to_screen_position(path[i]), Color.YELLOW, 3.0)

	if path.size() > 0:
		draw_circle(to_screen_position(path[path.size() - 1]), 8.0, Color.RED)
