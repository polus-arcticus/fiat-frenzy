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
var story_verbs: StoryVerbs
var screens: ScreenStack
var intro: IntroController
var collapse: CollapseController
var map_screen: MapScreen
var gun_tree_screen: GunTreeScreen  # U: the money gun's upgrades
var dialogue: DialogueScreen
var sage_controller: SageController
var bike_controller: BikeController
var placement: PlacementController  # putting a tent or a barrel fire down (see Placing)
var skate_controller: SkateController
var inspector: InspectorController
var portal_controller: PortalController
var quest_controller: QuestController
var bus: BusView
var shuttle: ShuttleView   # the golf cart at the European Central Bank's gate (null if the map has no gate)
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
var pause: PauseScreen
var dev_stages: DevStageController
var _since_autosave := 0.0
var _last_day := -1
var _chapters_written := {}  # the checkpoints this run has already written

const AUTOSAVE_EVERY := 240.0  # real seconds between autosaves



func _ready() -> void:
	process_physics_priority = -10  # the sim steps first each physics frame, then the views that follow it, then the player
	Controls.register()
	var args := OS.get_cmdline_user_args()
	var load_slot := Launch.take_slot()
	skip_intro = skip_intro or "--skip-intro" in args or load_slot != "" or Launch.skip_intro
	var district := _load_district()
	_build_town(district)
	_build_player()
	world.begin_play()  # the town is built: whatever turns up from now on is named after this game (see World.mint)
	_build_screens(district)
	_build_story()
	presenter = HudPresenter.new(world, hud, player, gun, inventory, tutorial, marker)
	hud.notify("Click to capture the mouse.")
	if load_slot != "":
		if not load_game(load_slot):
			hud.notify("That save could not be read: starting fresh.")
	_last_day = world.clock.day()
	dev_stages = DevStageController.new().setup(self)
	add_child(dev_stages)
	for a in args:
		if a.begins_with("--stage="):
			_jump_when_free(a.trim_prefix("--stage="))


## `--stage=<id>`: once the hero is free to move (the intro, if there is one, is over), play the story forward to there.
func _jump_when_free(id: String) -> void:
	while not player.controls_enabled:
		await get_tree().process_frame
	dev_stages.go(id)


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
	WorldViews.spawn(self, world, scenario.facing)
	StoryViews.spawn(self, world, scenario)
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
	story_verbs = StoryVerbs.new().setup(world, interaction)  # (the story's talks: Q at its people)
	add_child(interaction)
	bike_controller = BikeController.new().setup(world, player, gun, hud)
	add_child(bike_controller)
	skate_controller = SkateController.new().setup(world, player, gun, hud)
	add_child(skate_controller)
	placement = PlacementController.new().setup(world, player, gun, hud)
	add_child(placement)
	interaction.place_requested.connect(placement.begin)
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
	# On the bus the hero's controls are off for the ride: the stack gives them back whenever a screen closes, so take them
	# off again (it is connected after the stack's own handler, so it runs after it).
	map_screen.closed.connect(func():
		if player.is_seated():
			player.controls_enabled = false)
	inventory.closed.connect(func():  # (and so the bag, which can be opened from a seat)
		if player.is_seated():
			player.controls_enabled = false)
	gun_tree_screen = GunTreeScreen.new()
	add_child(gun_tree_screen)
	screens.register(gun_tree_screen)
	fade = FadeScreen.new()
	add_child(fade)
	pause = PauseScreen.new()
	pause.stages = DevStageController.STAGES
	add_child(pause)
	screens.register(pause)
	pause.save_requested.connect(func(): pause.say("Saved." if save_game("manual") else "Could not save."))
	pause.title_requested.connect(_to_title)
	pause.chapter_requested.connect(_to_chapter)
	pause.stage_requested.connect(func(id: String):
		pause.close()
		dev_stages.go(id))
	pause.opened.connect(func(): sim.hold("pause"))
	pause.closed.connect(func(): sim.hold("pause", false))
	screens.mouse_freed.connect(func(): if not intro.running: pause.open())


## What happens to the hero: the conversations, the bus, passing out, and the opening crash.
func _build_story() -> void:
	sage_controller = SageController.new().setup(world, player, hud, dialogue, self)
	add_child(sage_controller)
	bus = BusView.new().setup(scenario.bus_stop.pos, scenario.bus_stop.yaw)
	bus.follow(world.bus, sim)
	add_child(bus)
	if world.shuttle != null:
		shuttle = ShuttleView.new().setup(world.shuttle.pos, VehicleView._yaw_of(world.shuttle.heading))
		shuttle.follow(world.shuttle, sim)
		add_child(shuttle)
	quest_controller = QuestController.new().setup(world, player, hud, dialogue, self, scenario, bus, fade, shuttle)
	add_child(quest_controller)
	interaction.talk_requested.connect(func(who: Drone):
		if who == world.cast.sage:
			sage_controller.talk()
		else:
			quest_controller.talk(who))
	interaction.board_prompt = quest_controller.board_prompt
	interaction.board_requested.connect(quest_controller.board)
	collapse = CollapseController.new().setup(world, player, hud, screens, gun)
	add_child(collapse)
	inspector = InspectorController.new().setup(world, player, gun, screens, self)
	add_child(inspector)
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


## Views for what has turned up in the model since the last look (see World.arrivals).
func _views_for_arrivals() -> void:
	for thing in world.arrivals:
		WorldViews.add(self, world, thing)
	world.arrivals.clear()


## Keeps the player's body and the model in step: reacts to passing out, and otherwise the body is the
## truth for where the player is. While out cold, the model says where they are.
func _sync_player() -> void:
	collapse.update()
	if world.player.care == "":
		world.player.pos = player.ground_pos()
		presenter.picked_up(world.commerce.pick_up_cash())
	bike_controller.sync()
	portal_controller.update()


func _process(delta: float) -> void:
	_views_for_arrivals()
	_autosave(delta)
	_checkpoint()
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
		var may_look := player.controls_enabled or player.is_seated()  # (the map can be watched from a seat on the bus)
		if may_look and world.player.care == "" and not inventory.visible and not dialogue.visible and not map_screen.visible:
			map_screen.open()
			get_viewport().set_input_as_handled()
	elif e.is_action_pressed("gun_tree"):
		if gun_tree_screen.visible:
			gun_tree_screen.close()
		elif player.controls_enabled and world.gun_owned:
			gun_tree_screen.open(world)
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F5:
		save_game("quicksave")
	elif e.is_action_pressed("speed"):
		sim.cycle_speed()


# ---------------------------------------------------------------- saving and loading

## Whether the world is at rest enough to be written down: not mid-intro, not on the bus ride, not passed out.
func can_save() -> bool:
	return not intro.running and not quest_controller.riding_the_bus and world.player.care == "" and not world.hero.mode == Hero.Mode.SEATED


## What the model cannot say: where the hero looks, and the scene bits the controllers keep.
func _hero_state() -> Dictionary:
	return {"yaw": player.rotation.y, "pitch": player.camera.rotation.x, "third_person": player.wanted_third_person,
		"gun_mode": gun.mode, "quest": quest_controller.save_state()}


## Writes the game to `slot`. False if it could not be (or is not at a point where it can be).
func save_game(slot: String) -> bool:
	if not can_save():
		hud.notify("Not now.")
		return false
	var ok := SaveStore.write(slot, world, _hero_state())
	if ok and slot != SaveStore.AUTOSAVE:
		hud.notify("Game saved.")
	return ok


## Lays a save over the freshly built town. The scenario made everything that is always there; the save says what has
## changed (see Snapshot), and the views that were made from the fresh world are brought up to date.
func load_game(slot: String) -> bool:
	var doc := SaveStore.read(slot)
	if doc.is_empty():
		return false
	Snapshot.new(world).apply(doc.world)
	_views_for_arrivals()  # (what the save had that the fresh town did not: latecomers, found clusters)
	var h: Dictionary = doc.hero
	world.hero.mode = Hero.Mode.ON_FOOT  # back on their feet: the bike and board wait where they were left
	world.skating.speed = 0.0
	player.teleport(Vector3(world.player.pos.x, 0.1, world.player.pos.y), float(h.get("yaw", 0.0)))
	player.camera.rotation.x = float(h.get("pitch", 0.0))
	player.set_third_person(h.get("third_person", false))
	gun.mode = h.get("gun_mode", "gift")
	gun.set_enabled(world.gun_owned)
	quest_controller.load_state(h.get("quest", {}))
	tutorial.update(world.player.pos)
	tutorial.take_news()  # (what was done before the save is not news)
	sky.update(world.clock.fraction())
	return true


## An autosave now and then, and at each dawn, whenever the moment allows it.
func _autosave(delta: float) -> void:
	_since_autosave += delta
	var day := world.clock.day()
	var dawn := day != _last_day
	_last_day = day
	if (_since_autosave >= AUTOSAVE_EVERY or dawn) and can_save() and player.controls_enabled:
		_since_autosave = 0.0
		save_game(SaveStore.AUTOSAVE)


## The first time the story reaches a chapter's start, and the hero is somewhere that can be saved, the game writes its checkpoint.
func _checkpoint() -> void:
	if not (can_save() and player.controls_enabled):
		return
	var q := world.quests
	var reached := ""
	if q.active() == QuestBook.LETTER and not q.done("rode_bus"):
		reached = "chapter-letter"
	if q.active() == QuestBook.LETTER and q.done("rode_on") and not q.done("cleared_gate"):
		reached = "chapter-bank"
	if reached != "" and not _chapters_written.has(reached):
		_chapters_written[reached] = true
		SaveStore.write(reached, world, _hero_state())
		hud.notify("Checkpoint: %s" % SaveStore.CHAPTERS[reached])


## Back to a checkpoint: the whole scene is built again (a save is laid over a fresh town), through the loading screen.
func _to_chapter(slot: String) -> void:
	sim.hold("pause", false)
	Launch.skip_intro = false
	Launch.begin(get_tree(), slot)


func _to_title() -> void:
	sim.hold("pause", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://title.tscn")
