class_name InputHandler
extends Node

signal spin_requested
signal skip_requested
signal turbo_mode_updated
signal toggle_quickspin
signal toggle_audio
signal set_volume
signal stop_requested
signal increase_bet_requested
signal decrease_bet_requested
signal start_replay

onready var timer: Timer = $Timer

export var turboModeDelay:float
export var spinRequestDelay:float
export(NodePath) var hud_landscape_path; onready var hud_landscape := get_node(hud_landscape_path) as GameUI

var turboMode : bool setget set_turbo_mode
var quickMode = false
var isMuted = false

func _ready():
	timer.connect("timeout", self, "onTimerTimeout")
	yield(get_tree(), "idle_frame")
	if hud_landscape: # HUD Connections
		connectHUD(hud_landscape)

func _input(event: InputEvent) -> void:
	# Handle Space Button
	if event.is_action_pressed("spin"):
		onStopPressed()
		onSpinPressed()
		emit_signal("skip_requested")
	elif event.is_action_released("spin"):
		onSpinReleased()
	
	# Handle Mouse Release over Spin Button
	if event is InputEventMouseButton && !Input.is_action_pressed("spin"):
		onSpinReleased()
	
	# Handle QuickSpin Button
	if event.is_action_pressed("toggle_quickspin"):
		onQuickSpinToggle()
	
func onSpinPressed():
	timer.start(turboModeDelay)
	emit_signal("spin_requested")

func onBetDecrease():
	emit_signal("decrease_bet_requested")

func onBetIncrease():
	emit_signal("increase_bet_requested")

func onSpinReleased():
	timer.stop()
	set_turbo_mode(false)
	
func onStopPressed():
	emit_signal("stop_requested")

func onTimerTimeout():
	timer.stop()
	set_turbo_mode(true)
	
	timer.start(turboModeDelay)
	onSpinPressed()

func onQuickSpinToggle():
	quickMode = not quickMode
	emit_signal("toggle_quickspin", quickMode)
	if hud_landscape:
		hud_landscape.emit_signal("set_quickspin_toggle", quickMode)
	
func setQuickSpin(value: bool):
	if quickMode == value:
		return
	onQuickSpinToggle()

func onAudioToggle():
	pass

func set_turbo_mode(value: bool):
	if turboMode != value:
		turboMode = value
		emit_signal("turbo_mode_updated", turboMode)

func connectHUD(hud:GameUI):
	hud.connect("on_spin_pressed", self, "onSpinPressed")
	hud.connect("on_stop_pressed", self, "onStopPressed")
	hud.connect("on_spin_released", self, "onSpinReleased")
	hud.connect("on_stop_released", self, "onSpinReleased")
	hud.connect("on_quickspin_toggled", self, "onQuickSpinToggle")
	hud.connect("on_bet_decrease_pressed", self, "onBetDecrease")
	hud.connect("on_bet_increase_pressed", self, "onBetIncrease")
	hud.connect("on_audio_toggled", self, "onAudioToggle")
	hud.connect("on_autoplay_pressed", self, "onAutoplayPressed")
	hud.connect("on_confirm_autoplay_pressed", self, "onAutoplayConfirmed_BuiltIn", [hud])
	hud.connect("on_autoplay_stop_on_bonus_toggled", self, "onStopOnBonusToggled") 
