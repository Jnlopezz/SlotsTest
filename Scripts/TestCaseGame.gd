class_name GameManager
extends Node

## THIS IS WHERE CANDIDATES RESPONSIBLE TO IMPLEMENT THEIR TASK REQUIREMENTS
##
## GAME MANAGER script is responsible for followings:
## - Operates all modules.
## - Connect modules between each other
## - Regulate Game State
## - Make the game logic works
## 
## In this lite version of slot game you are expected to
## 1) Inspect overall structure of the code provided
## 2) Communicate with SlotVisual module to make it Spin and Stop
## 3) Show Winlines if there are any while animating corresponding Symbols
## 4) Show following messages on Primary Text Area through GameUI:
##	-- During spin, "Good Luck"
##	-- During stop, "Press Spin Button"
##	-- During win, "You won [win amount]"
## 5) Implement QuickSpin Logic by reading InputHandler signals
## 6) Implement the following bonus game logic:
##	-- When more than one WILD lands, beginning from the top left most wild,
##		--- A molotov appears and thrown to the following wilds location
##		--- As the molotov lands, provided molotov animation plays
##		--- During the explosion animation the multiplier increases by one (e.g. x1 -> x2, x4 -> x5 etc.)
##		--- Then another molotov thrown to folowing Wild symbols and so on...
##	-- If player interrupts by spin button, all sequence skipped and symbols updated automatically
##	-- Shows paylines after explosion sequence ends
##	-- You can use the video attached as reference
##
## == Created for Topgaming Ltd. 2025 ==

onready var backend : VirtualBackend = $"../VirtualBackend"
onready var game_hud : GameUI = $"../GameHUD"
onready var input_handler : InputHandler = $"../InputHandler"
onready var slot_visual : SlotVisual = $"../SlotVisual"

var currentResult: SpinResult

func _ready() -> void:
	Engine.set_target_fps(90)
	
	yield(get_tree(), "idle_frame")
	backend.connect("connection_established", self, "_on_connection_established")
	backend.emit_signal("connection_request")

func _on_connection_established(data) -> void:
	print("_on_connection_established")
	backend.connect("spin_result_ready", self, "_on_spin_result_ready")
	_prepare_input_handler()
	_prepare_slot_visual()
	_prepare_game_hud()
	pass

func _prepare_input_handler():
	input_handler.connect("toggle_quickspin", self, "_on_quick_spin_toggle")
	input_handler.connect("spin_requested", self, "_start_spin")
	pass

func _prepare_slot_visual():
	slot_visual.connect("slot_status_updated", self, "_on_slot_status_update")
	slot_visual.connect("on_reel_stopping", self, "_on_reel_stopping")
	slot_visual.connect("on_reel_stopped", self, "_on_reel_stop")
	slot_visual.connect("on_slot_stopped", self, "_on_slot_stopped")

func _prepare_game_hud():
	game_hud.emit_signal("on_main_message_updated", tr("message.press-spin"))
	game_hud.emit_signal("on_bet_amount_updated", backend.betAmounts[backend.currentBetIndex])
	game_hud.emit_signal("on_balance_updated", backend.balance)

func _start_spin() -> void:
	print("_start_spin")
	# Spin Started
	slot_visual.emit_signal("start_spin")
	game_hud.emit_signal("on_main_message_updated", tr('message.greeting'))

func _stop_spin() -> void:
	print("_stop_spin" + str(currentResult))


func _on_slot_status_update(status) -> void:
	print("_on_slot_status_update " + str(Enumerations.SLOTSTATE.keys()[status]))
	match status:
		Enumerations.SLOTSTATE.SPINNING:
			backend.emit_signal("spin_requested")
		
		Enumerations.SLOTSTATE.SHOW_WIN:
			slot_visual.onWinState(currentResult.paylineId)
			game_hud.emit_signal("on_win_message_updated", currentResult.totalWin, tr('message.won-spins'))
			slot_visual.set_slot_status(Enumerations.SLOTSTATE.READY)
		

func _on_reel_stop(reelIndex: int) -> void:
	var win_symbols_in_index = []
	
	for win in currentResult.winSymbolPositions:
		if reelIndex < win.size():
			win_symbols_in_index.append(win[reelIndex])
		
	if win_symbols_in_index.size() > 0:
		slot_visual.animateSymbol(reelIndex, win_symbols_in_index)


func _on_reel_stopping(reelIndex: int) -> void:
	pass


func _on_slot_stopped() -> void:
	if currentResult.totalWin > 0:
		slot_visual.set_slot_status(Enumerations.SLOTSTATE.SHOW_WIN)
	else:
		game_hud.emit_signal("on_main_message_updated", tr('message.press-click-spin'))
		slot_visual.set_slot_status(Enumerations.SLOTSTATE.READY)


func _on_spin_result_ready(result: SpinResult) -> void:
	print("_on_spin_result_ready\n" + result.printValues(["symbols", "totalWin"]))
	currentResult = result
	slot_visual.emit_signal("stop_spin", result.symbols)

func _on_quick_spin_toggle(value: bool) -> void:
	pass

func _on_turbo_spin_toggle(value: bool) -> void:
	pass
