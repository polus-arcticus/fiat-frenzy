## CONTROLLER. The root of the game. Owns the model (a World), builds the views that draw it, steps the
## simulation from real time, and wires the player, the gun, the HUD and the tutorial together. The model
## knows nothing of any of this; the views only read it.
extends Node3D

const DISTRICT_PATH := "res://data/bahnhofsviertel.json"
const SIM_STEP := SimLoop.STEP

var world: World
var scenario: Scenario
var city: Node3D
var sky: DayNight
var player: PlayerController
var gun: GunController
var hud: Hud
var marker: MarkerView
var tutorial: Tutorial
var inventory: InventoryScreen
var interaction: InteractionController
var screens: ScreenStack
var intro: IntroController
var collapse: CollapseController
var map_screen: MapScreen
var dialogue: DialogueScreen
var sage_controller: SageController
var bike_controller: BikeController
var skate_controller: SkateController
var portal_controller: PortalController
var quest_controller: QuestController
var bus: BusView
var fade: FadeScreen
## Set before the scene is added, or pass --skip-intro: starts the game at once, with the gun in hand.
var skip_intro := false
var sim: SimLoop
## Whether anything is holding the sim still. Setting it is a plain manual hold, for tests and tools.
var sim_paused: bool:
	get:
		return sim.paused()
	set(on):
		sim.hold("manual", on)
var bills_view: BillsView

var presenter: HudPresenter



func _ready() -> void:
	process_physics_priority = -10  # the sim steps first each physics frame, then the views that follow it, then the player
	Controls.register()
	var args := OS.get_cmdline_user_args()
	skip_intro = skip_intro or "--skip-intro" in args
	var district := _load_district()
	_build_town(district)
	_build_player()
	_build_screens(district)
	_build_story()
	presenter = HudPresenter.new(world, hud, player, gun, inventory, tutorial, marker)
	hud.notify("Click to capture the mouse.")


## The map, the sky and the model, and the views that draw what the model starts with.
func _build_town(district: Dictionary) -> void:
	scenario = Scenario.new(district)
	city = CityBuilder.build(district, scenario.openings())
	add_child(city)
	sky = DayNight.new()
	add_child(sky)
	sky.lit_windows = city.get_node("LitWindows")
	world = scenario.build()
	sim = SimLoop.new(world)
	WorldViews.spawn(self, world, scenario)
	bills_view = BillsView.new().setup(world)
	add_child(bills_view)


## The hero: the HUD, the body, the gun in their hand, the beacon, and what they can interact with.
func _build_player() -> void:
	hud = Hud.new()
	add_child(hud)
	player = PlayerController.new()
	add_child(player)
	player.teleport(Vector3(scenario.start.x, 0.1, scenario.start.y), scenario.start_yaw)
	world.add_player(scenario.start)
	gun = GunController.new()
	player.camera.add_child(gun)
	gun.position = Vector3(0.2, -0.22, -0.4)
	gun.scale = Vector3.ONE * 0.75
	gun.setup(world, player.camera)
	gun.fx_root = self
	gun.applied.connect(hud.notify)
	marker = MarkerView.new()
	add_child(marker)
	gun.set_enabled(skip_intro)
	world.gun_owned = skip_intro
	tutorial = Tutorial.new(world, scenario.cast, not skip_intro)
	inventory = InventoryScreen.new()  # added last, so it sees input first
	add_child(inventory)
	interaction = InteractionController.new().setup(world, player, hud, inventory)
	add_child(interaction)
	bike_controller = BikeController.new().setup(world, player, gun, hud)
	add_child(bike_controller)
	skate_controller = SkateController.new().setup(world, player, gun, hud)
	add_child(skate_controller)
	player.view_changed.connect(_on_view_changed)
	portal_controller = PortalController.new().setup(world, player, hud)
	add_child(portal_controller)


## The full-screen screens, all registered with the stack (which owns Esc and the player's controls while one is open).
func _build_screens(district: Dictionary) -> void:
	screens = ScreenStack.new()
	screens.player = player
	add_child(screens)
	screens.register(inventory)
	dialogue = DialogueScreen.new()  # after the inventory, so it sees input first
	add_child(dialogue)
	screens.register(dialogue)
	map_screen = MapScreen.new().setup(district, world, player, func(): return presenter.current_marker(), scenario.landmarks(world))
	add_child(map_screen)
	screens.register(map_screen)
	map_screen.opened.connect(func(): hud.show_prompt(""))
	fade = FadeScreen.new()
	add_child(fade)


## What happens to the hero: the conversations, the bus, passing out, and the opening crash.
func _build_story() -> void:
	sage_controller = SageController.new().setup(world, player, hud, dialogue, self)
	add_child(sage_controller)
	bus = BusView.new().setup(scenario.bus_stop.pos, scenario.bus_stop.yaw).follow(world.bus, sim)
	add_child(bus)
	quest_controller = QuestController.new().setup(world, player, hud, dialogue, self, scenario, bus, fade)
	add_child(quest_controller)
	interaction.talk_requested.connect(func(who: Drone):
		if who == world.sage_drone:
			sage_controller.talk()
		else:
			quest_controller.talk(who))
	interaction.can_board = quest_controller.can_board
	interaction.board_requested.connect(quest_controller.board)
	collapse = CollapseController.new().setup(world, player, hud, screens, gun)
	add_child(collapse)
	intro = IntroController.new().setup(world, player, hud, scenario, self, add_drone_view)
	add_child(intro)
	intro.pickup_spawned.connect(_on_pickup_spawned)
	intro.finished.connect(func(): sim.hold("intro", false))
	if not skip_intro:
		sim.hold("intro")
		intro.start()


func _load_district() -> Dictionary:
	var f := FileAccess.open(DISTRICT_PATH, FileAccess.READ)
	assert(f != null, "missing %s: run tools/osm_to_district.py" % DISTRICT_PATH)
	return JSON.parse_string(f.get_as_text())


## Makes the view for a drone, including one that turns up later (the bankers).
func add_drone_view(d: Drone) -> DroneView:
	return WorldViews.drone_view(self, world, d)


func _physics_process(delta: float) -> void:
	sim.update(delta)


## Runs `sim_seconds` of game time at once, the way the real loop would (the player is kept in step with the
## model each tick), without waiting for frames. For tests and tools.
func advance(sim_seconds: float) -> void:
	for i in ceili(sim_seconds / SIM_STEP):
		_sync_player()
		world.tick(SIM_STEP)
	_sync_player()


## Keeps the player's body and the model in step: reacts to passing out, and otherwise the body is the
## truth for where the player is. While out cold, the model says where they are.
func _sync_player() -> void:
	collapse.update()
	if world.player.care == "":
		world.player.pos = player.ground_pos()
		presenter.picked_up(world.cash.collect_for_player())
	bike_controller.sync()
	portal_controller.update()


func _process(delta: float) -> void:
	_sync_player()
	sky.update(world.clock.fraction())
	presenter.update(delta, sim.speed)


## First or third person: the gun is held up in front of the camera in first person, and in front of the hero's head in
## third; the bicycle's handlebars are only for the saddle's own view.
func _on_view_changed(third_person: bool) -> void:
	gun.reparent(player.head if third_person else player.camera, false)
	gun.position = Vector3(0.42, -0.5, -0.6) if third_person else Vector3(0.2, -0.22, -0.4)
	gun.scale = Vector3.ONE * (0.9 if third_person else 0.75)
	bike_controller.refresh_view()


func _on_pickup_spawned(pickup: GunPickupView) -> void:
	pickup.taken.connect(func():
		gun.set_enabled(true)
		world.gun_owned = true
		hud.show_caption("Hold left mouse to print money. Try it on the locals.", 4.0))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and player.controls_enabled:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			gun.cycle_mode(-1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			gun.cycle_mode(1)
	elif e.is_action_pressed("map"):
		if player.controls_enabled and not inventory.visible and not dialogue.visible and not map_screen.visible:
			map_screen.open()
			get_viewport().set_input_as_handled()
	elif e.is_action_pressed("speed"):
		sim.cycle_speed()
