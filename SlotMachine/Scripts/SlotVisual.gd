class_name SlotVisual
extends Control

## This Class is responsible for a Reel Based Slot Visualization.
## It has several number of Reels.
## SlotVisual sends signals to reels for:
## 	- Creating Reels
## 	- Spin and Stop Reels
## 	- Showing Winning Symbols
##
## == Created for Topgaming Ltd. 2023 by Semih Bertug Benim ==

# SIGNALS
#####################################

signal create_slot_symbols
signal create_anticipation_frame
signal show_win
signal animate_symbol
signal blackout_all_symbols
signal highlight_all_symbols
signal stop_all_symbols
signal slot_status_updated
signal on_reel_stopping
signal on_reel_stopped
signal on_anticipation_started
signal on_slot_stopped
signal start_spin
signal stop_spin
signal skip_spin
signal set_animation_speed
signal set_anticipation_reels
signal emit_all_reels
signal bring_symbol_front
signal update_symbols
signal update_symbol
signal set_quick_mode
signal set_symbol_orders

# CONSTANTS
#####################################

## Default Z Order for winning symbols
## Not Constant! Set during start by the reel sizes
var Z_ORDER_WIN

# EXPORT VARIABLES 
#####################################

# Defines the spin speed. Default is 40
export var spinSpeed: float = 20
# Defines reels to spin after previous reel started to spin
# It makes reels wait for a duration after previous reel started to spin
export var startDelayBetweenReels: float
# Defines reels stop time after previous reel stop
export var stopDelayBetweenReels: float
# Defines reels stop time after previous reel stop during the QuickSpin
export var stopDelayBetweenReels_quick: float

# Contains symbols
export(NodePath) var reelContainer: NodePath
## Delay Multiplier for Anticipating Reels
## Can be modified with "set_anticipation_delay
export var stopDelayBetweenReels_Anticipation: float

# PRIVATE VARIABLES
#####################################

# Contains a Reel Array
var reels
# Contains latest result as doublearray as indexes
var symbolIndexes
# A Reused Random Number Generator
var rand_generate:RandomNumberGenerator
# Slots current status whether it is ready to Spin or Showing Results etc.
var slot_status setget set_slot_status, get_slot_status
# Defines a Tween for create a delayed spin sequence between Reels
var slotSpinTween:SceneTreeTween
# Defines a Tween for create a delayed stop sequence between Reels
var slotStopTween:SceneTreeTween
# Defines anticipation reel indexes for current spin
var anticipationReelIndexes:Array
## Slot Tween Animation Speed Multiplier
## Can be modified with "set_animation_speed" signal
## Should only be adjusted before the animation
var animationSpeed = 1
## Defines Reel Start and Stop tweens according to this value
## Set with set_quick_mode signal
var isQuickMode:bool = false
## Defines Symbol Z_Order Priorities if index exists in the Dictionary
## Prior SymbolIndex overrides the latter SymbolIndex
## If it doesnt exists in Dictionary it applies regular ordering
var SymbolZPriorities:Dictionary = {}

# FUNCTIONS
#####################################

func _ready():
	rand_generate = RandomNumberGenerator.new()
	reels = get_node(reelContainer).get_children()
	if reels == null or reels.size() == 0:
		printerr("Reels are not initialized. Terminating...")
		get_tree().quit()
	connect("create_slot_symbols", self, "createSymbols")
	connect("create_anticipation_frame", self, "createAnticipationFrame")
	connect("set_animation_speed", self, "setAnimationSpeed")
	connect("set_anticipation_reels", self, "setAnticipationReels")
	connect("emit_all_reels", self, "emitAllReels")
	connect("animate_symbol", self, "animateSymbol")
	connect("blackout_all_symbols", self, "blackoutAllSymbols")
	connect("highlight_all_symbols", self, "highlightAllSymbols")
	connect("stop_all_symbols", self, "stopAllSymbols")
	connect("bring_symbol_front", self, "bringSymbolForward")
	connect("update_symbols", self, "updateSymbols")
	connect("update_symbol", self, "updateSymbol")
	connect("set_quick_mode", self, "onSetQuickMode")
	connect("set_symbol_orders", self, "setSymbolOrders")
	
#	yield(get_tree(), "idle_frame")
	emit_signal("create_slot_symbols", reel_symbols, pseudo_symbol_indexes, [3,3,3,3,3]) #For Debugging Symbols

# SIGNAL FUNCTIONS
#####################################

## Creates Reels with given Symbol Visual Paths.
func createSymbols(SymbolArray, PseudoReelIndexes, rowCounts):
	
	symbolIndexes = []
	symbolIndexes.resize(reels.size())
	
	for reelIndex in reels.size():
		reels[reelIndex].emit_signal("set_row_count", rowCounts[reelIndex])
		reels[reelIndex].emit_signal("update_symbols", SymbolArray, PseudoReelIndexes[reelIndex])
		reels[reelIndex].connect('on_reel_stopping', self, "onReelStopping", [reelIndex])
		reels[reelIndex].connect('on_reel_stopped', self, "onReelStopped", [reelIndex])
		symbolIndexes[reelIndex] = []
		symbolIndexes[reelIndex].resize(rowCounts[reelIndex])
	
	# Calculate Z_ORDER Default Values for later use
	Z_ORDER_WIN = reels.size() + reels[0].screen_symbol_count
	
	set_slot_status(Enumerations.SLOTSTATE.READY)
	# Connect Signals related to Spin Actions
	connect("start_spin", self, "onStartSpin")
	connect("stop_spin", self, "onStopSpin")
	connect("skip_spin", self, "onSkipSpin")

## Starts Spinning Symbols
## To Spin certain reels only, reelIndex array needs to be passed
func onStartSpin(reelIndexes = []):
	if slot_status != Enumerations.SLOTSTATE.READY:
		return
	set_slot_status(Enumerations.SLOTSTATE.SPIN_BEGIN)
	
	anticipationReelIndexes = []
	
	slotSpinTween = create_tween().set_speed_scale(animationSpeed)
	
	# Highlight all symbols before Spin
	highlightAllSymbols()
	
	if reelIndexes.size() == 0:
		for reel in reels:
			reel.spin_speed_anticipation = spinSpeed / 4
			slotSpinTween.tween_callback(reel, "emit_signal", ["spin_reel", spinSpeed]).set_delay(startDelayBetweenReels)
	else:
		for reelIndex in reelIndexes:
			reels[reelIndex].spin_speed_anticipation = spinSpeed / 4
			slotSpinTween.tween_callback(reels[reelIndex], "emit_signal", ["spin_reel", spinSpeed]).set_delay(startDelayBetweenReels)
	slotSpinTween.tween_callback(self, "set_slot_status", [Enumerations.SLOTSTATE.SPINNING]).set_delay(0.2)
	
func onStopSpin(reelSymbols: Array, anticipationReels: Array = []):
	if slot_status != Enumerations.SLOTSTATE.SPINNING:
		printerr("Reels Didnt Start Spinning Completely!")
		return
	
	if anticipationReels.size() > 0:
		emit_signal("set_anticipation_reels", anticipationReels)
	
	slotStopTween = create_tween().set_speed_scale(animationSpeed)
	
	set_slot_status(Enumerations.SLOTSTATE.STOPPING)
	
	if reelSymbols.size() == 0: # Empty Array input for Debugging
		for reelIndex in reels.size():
			rand_generate.randomize()
			if reelIndex > 0:
				slotStopTween.tween_interval(stopDelayBetweenReels)
			slotStopTween.tween_callback(reels[reelIndex], "emit_signal" , ["stop_reel", []])
	else:
		if reels.size() != reelSymbols.size():
			printerr("Result Array Size is mismatched with Reel Amount")
		for reelIndex in range(reelSymbols.size()):
			# Show Anticipation FX on Reel if any
			slotStopTween.tween_callback(reels[reelIndex], "emit_signal", ["stop_reel", reelSymbols[reelIndex]])
			symbolIndexes[reelIndex] = reelSymbols[reelIndex].duplicate(true)
			if anticipationReelIndexes.has(reelIndex):
				slotStopTween.tween_interval(stopDelayBetweenReels_Anticipation) # + 1 / reels[reelIndex].spin_speed_anticipation)
#				print(str(stopDelayBetweenReels_Anticipation))
			elif anticipationReelIndexes.has(reelIndex + 1): ## HACK: To Sync Spin Time during Anticipation
				slotStopTween.tween_interval(stopDelayBetweenReels_Anticipation  * 0.7) # + 1 / reels[reelIndex].spin_speed_anticipation)
#				print(str(stopDelayBetweenReels_Anticipation  * 0.7))
			elif isQuickMode:
				slotStopTween.tween_interval(stopDelayBetweenReels_quick) # + 1 / reels[reelIndex].spin_speed)
			else:
				slotStopTween.tween_interval(stopDelayBetweenReels) # + 1 / reels[reelIndex].spin_speed)

func onSkipSpin(reelSymbols: Array):
#	if slot_status != Enumerations.SLOTSTATE.STOPPING:
#		return
	
#	print_debug("current state: SKIPPED")
	set_slot_status(Enumerations.SLOTSTATE.SKIPPED)
	
	# Abort Stop Sequence on Skip
	if slotStopTween:
		slotStopTween.kill()
	
	if reelSymbols.size() == 0:
		for reel in reels:
			rand_generate.randomize()
			reel.emit_signal("skip_reel", [])
	else:
		for reelIndex in reelSymbols.size():
			if reels[reelIndex].getReelStatus() !=  Enumerations.REELSTATE.READY:
				reels[reelIndex].emit_signal("skip_reel", reelSymbols[reelIndex])
				symbolIndexes[reelIndex] = reelSymbols[reelIndex].duplicate(true)

func onReelStopped(reelIndex):
		
	emit_signal("on_reel_stopped", reelIndex)
#	reels[reelIndex].emit_signal("hide_frame", Enumerations.AnticipationFX)
#	print(str(Time.get_ticks_msec()))
		
	if checkReelsReady() == true:
		yield(get_tree(), "idle_frame")
		set_slot_status(Enumerations.SLOTSTATE.READY)
#		print_debug("current state: READY")
		emit_signal("on_slot_stopped")
	else: ## Not Ready
		if anticipationReelIndexes.has(reelIndex+1):
			reels[reelIndex+1].emit_signal("anticipation_reel")
			emit_signal("on_anticipation_started", reelIndex+1)

func onReelStopping(reelIndex):
	emit_signal("on_reel_stopping", reelIndex)

## Modify the animationSpeed value
## It effects the spin and stop tweens speed scales
func setAnimationSpeed(value: float):
	animationSpeed = value
	for reel in reels:
		reel.emit_signal("set_animation_speed", animationSpeed)

## Sets anticipation reels
## It effects Spin and Stop animations
func onSetQuickMode(value: bool):
	isQuickMode = value

## Blackouts Symbols in all reels
func blackoutAllSymbols():
	for reel in reels:
		reel.emit_signal("blackout_symbols") # Darken all symbols in reels

func stopAllSymbols():
	for reel in reels:
		reel.emit_to_symbols("stop_symbol_animation")

func highlightAllSymbols():
	for reel in reels:
		reel.emit_signal("highlight_symbols") # Darken all symbols in reels

## Animate the Symbol on given indexes
func animateSymbol(reelIndex:int, targetSymbolIndexes:Array, animationName:String = ""):
	reels[reelIndex].emit_signal("animate_symbols", targetSymbolIndexes, animationName)

## Adds Symbols ZOrder with given index
func bringSymbolForward(reelIndex:int, symbolIndex:int, ZOrder:int):
	reels[reelIndex].emit_signal("bring_symbol_front", symbolIndex, ZOrder)

## Overrides Symbols ZOrder in given index
func setZOrder(reelIndex:int, symbolIndex:int, ZOrder:int):
	var arr = []
	arr[symbolIndex] = ZOrder
	reels[reelIndex].emit_signal("set_symbol_orders", arr)

func updateSymbol(colIndex: int, rowIndex: int, symbolData: SymbolData):
	reels[colIndex].emit_signal("update_symbol_data", rowIndex, symbolData)

func updateSymbols(symbolDatas: Array):
	for colIndex in symbolDatas.size():
		for rowIndex in symbolDatas[colIndex].size():
			if symbolDatas[colIndex][rowIndex]:
				updateSymbol(colIndex, rowIndex, symbolDatas[colIndex][rowIndex])

# HELPER FUNCTIONS
#####################################

# returns true if all reels is_ready value are true
func checkReelsReady() -> bool :
	for reel in reels:
		if not reel.is_ready():
			return false
	return true

# Setter of slot_status variable
func set_slot_status(value):
	slot_status = value
	emit_signal("slot_status_updated", slot_status)

# Getter of slot_status variable
func get_slot_status():
	return slot_status

# Emit following signal to all reels
func emitAllReels(signalMessage:String, params:Array=[]):
	for reel in reels:
		if params.size() == 0:
			reel.emit_signal(signalMessage)
		else:
			reel.emit_signal(signalMessage, params)

# DEBUG VARIABLES
# Used for Debugging and Testing the scene seperately.
#####################################

# Demo Symbol Visual Path
export(Array, Resource) var reel_symbols = []

var pseudo_symbol_indexes:Array =[
			[
			0,2,1,2,1,1,1,2,2,2,3,3,4,4,2
			],
			[
			0,2,3,2,1,1,1,2,2,2,3,3,4,4,2
			],
			[
			1,0,3,0,1,1,1,2,2,2,3,3,4,4,2
			],
			[
			2,0,3,0,1,0,1,2,4,2,3,3,4,4,2
			],
			[
			1,3,4,3,1,4,1,2,3,2,3,1,4,4,2
			]
		]
