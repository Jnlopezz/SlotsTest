class_name Reel
extends Control

## This Class is responsible for a single Reel in SlotVisual.
## It has several symbols that created automatically with update_symbols signal
## Reel acquire symbols for:
##  - Highlight or Blackout symbols
##  - Spin and Stop itself
##  - Showing Winning Symbols of the reels
##  - Creating a Pseudo reel during endless spin
##
## == Created for Topgaming Ltd. 2023 by Semih Bertug Benim ==

# SIGNALS
#####################################

signal update_symbols
signal highlight_symbols
signal blackout_symbols
signal animate_symbols
signal on_reel_stopping
signal on_reel_stopped
signal spin_reel
signal anticipation_reel
signal stop_reel
signal skip_reel
signal set_animation_speed
signal add_frame
signal show_frame
signal hide_frame
signal hide_all_frames
signal set_row_count
signal set_symbol_orders
signal bring_symbol_front
signal update_symbol_data

# CONSTANTS
#####################################

# EXPORT VARIABLES 
#####################################

## A Symbol Prefab to fill in Reel Containers.
export (PackedScene) var symbol_prefab: PackedScene
## Tint Color for symbols as they get darker
export (Color) var dark_color = Color.gray 
## Tint Color for symbols as they get darker
export (float) var tintDuration = 0.2 
## Expected symbol size
export (float) var symbol_size : float 
## Gives symbol animations a base value for adjusting Z Order
## Sums this value while adjusting Symbols Z Order
export var baseZOrder: int = 0
## symbol-based position. e.g 1 is second symbol position
export var scroll_position : float setget set_scroll_position 
## Create a gap between each symbol of the Reel
export (float) var symbol_offset : float
## Defines Starting Transition Curve
export (int,"TRANS_LINEAR", "TRANS_SINE", "TRANS_QUINT",
		"TRANS_QUART", "TRANS_QUAD", "TRANS_EXPO", "TRANS_ELASTIC",
		"TRANS_CUBIC","TRANS_CIRC", "TRANS_BOUNCE", "TRANS_BACK") var startTransition: int = 0
## Defines Starting Ease Type
export (int, "EASE_IN", "EASE_OUT", "EASE_IN_OUT", "EASE_OUT_IN") var startEase: int = 2
## Defines Starting Movement Speed.
## The value is applied only on [b]starting[\b] part of [b]reelMovementTween[\b]
export var startSpeed: float
## Defines Stopping Transition Curve
export (int,"TRANS_LINEAR", "TRANS_SINE", "TRANS_QUINT",
		"TRANS_QUART", "TRANS_QUAD", "TRANS_EXPO", "TRANS_ELASTIC",
		"TRANS_CUBIC","TRANS_CIRC", "TRANS_BOUNCE", "TRANS_BACK") var stopTransition: int = 0
## Defines Stopping Ease Type
export (int, "EASE_IN", "EASE_OUT", "EASE_IN_OUT", "EASE_OUT_IN") var stopEase: int = 2
## Defines Stopping Movement Speed.
## The value is applied only on [b]stopping[\b] part of [b]reelMovementTween[\b]
export var stopSpeed: float
## Is used for Unit Testing of Reel System
## Dynamically setup reel with debug reel and enables standalone spin functions
export var isUnitTesting: bool = false

## Contains Symbol Index that defines Pseudoreel during the spin.
## During spin, it selects the next symbol data from array.
export var pseudoReelIndexes: Array = []

# PRIVATE VARIABLES
#####################################

# Stores Reels Symbol Datas
var symbolDatas : Array

# All Symbols that are created for this Reel
var symbols : Array

# Total Symbol Count in the reel
var symbol_count : int

## Symbol Amount for imitating OffScreen Symbols.
## It uses smooth transition during spin Clamping
var offscreen_symbol_count : int

## Symbol Amount that will be kept on screen
var screen_symbol_count : int

## Flag for successful reel creation
var reelCreated : bool = false

## Reused tween for reel spin animation
var reelMovementTween : SceneTreeTween

## Defines the spin speed as the reel spin endlessly
var spin_speed : float

## Defines the spin speed as the reel start anticipation
var spin_speed_anticipation: float

## Flag for received Stop command
var stop_flag : bool = false

## Defines the scrollPosition of the reel that is going to be stopped at
var stop_index

## Reel Status if whether the reel is READY, STOPPING, STOPPED etc.
var reel_state = Enumerations.REELSTATE.READY

## Reel Tween Speed Multiplier
## Can be modified with "set_animation_speed" signal
## Can only be adjusted before the animation
var animationSpeed = 1

## Reel Frames to show during different type of events
## Set by addFrame, Show or Hide with showFrame, hideFrame, hideFrames
## e.g showFrame("AnticipationFrame")
var frames : Dictionary

## Reel Tween Mode refers to true if anticipation_reel signal triggered
## Reset to false after the reel stops
var is_anticipation = false

## True if the stop_reel signal used and Reel Start Stopping.
## Also prevents reel from Pseudo Reel Changing
var is_stop_requested = false

## It is the floor value of scroll_position.
## It is updated and used for making pseudoreel symbol changes
var last_position_change: int = -1

# ONREADY VARIABLES
#####################################

## Vertical Box Container to adjust size and position of created Symbols
onready var container:VBoxContainer = self.get_node("VBoxContainer") 

# FUNCTIONS
#####################################

func _ready():
	frames = {}
	# Connecting Signals
	connect("update_symbols", self, "onSymbolUpdate")
	connect("highlight_symbols", self, "onHighlightSymbols")
	connect("blackout_symbols", self, "onBlackoutSymbols")
	connect("animate_symbols", self, "onAnimateSymbols")
	connect("spin_reel", self, "startSpin")
	connect("anticipation_reel", self, "startAnticipationSpin")
	connect("stop_reel", self, "stopSpin")
	connect("skip_reel", self, "skipSpin")
	connect("set_animation_speed", self, "setAnimationSpeed")
	connect("add_frame", self, "addFrame")
	connect("show_frame", self, "showFrame")
	connect("hide_frame", self, "hideFrame")
	connect("hide_all_frames", self, "hideAllFrames")
	connect("set_row_count", self, "updateRowCount")
	connect("set_symbol_orders", self, "updateSymbolOrders")
	connect("bring_symbol_front", self, "bringSymbolForward")
	connect("update_symbol_data", self, "updateSymbolData")
	
# DEBUG SEQUENCE BELOW
#####################################
	if isUnitTesting:
		emit_signal("set_row_count", 3)
		emit_signal("update_symbols", debug_reelSymbols, debug_pseudoReel) 
#		connect("on_reel_stopped", self, "onBlackoutSymbols", [[]])
#		connect("on_reel_stopped", self, "onHighlightSymbols", [[]])
#		connect("on_reel_stopped", self, "onAnimateSymbols", [[0,2], "anim"])

var debug_symbol_index = 0

func _input(event):
	if isUnitTesting:
		if event.is_action_pressed("spin"):
			var rnd = RandomNumberGenerator.new()
			rnd.randomize()
			if reel_state == Enumerations.REELSTATE.READY:
				emit_signal("spin_reel", 6)
			elif is_anticipation:
				debug_symbol_index += 1 if debug_symbol_index < 3 else -3
				emit_signal("stop_reel", [debug_symbol_index,debug_symbol_index,debug_symbol_index])
			elif reel_state == Enumerations.REELSTATE.SPINNING:
				spin_speed_anticipation = spin_speed / 2
				emit_signal("anticipation_reel")
			elif reel_state == Enumerations.REELSTATE.STOPPING:
				emit_signal("skip_reel")
			else:
				print("Reel State Something Else: " + str(reel_state))
# END OF DEBUG SEQUENCE

# SIGNAL FUNCTIONS
#####################################

func updateRowCount(rowCount = -1):
	screen_symbol_count = int(get_rect().size.y / symbol_size) if rowCount < 0 else rowCount
	offscreen_symbol_count = screen_symbol_count

## Creates Symbols and Adjust the repeating symbols at the offscreen
func onSymbolUpdate(SymbolArray, PseudoReelIndexes):
	# assign Symbol Data Array
	symbolDatas = SymbolArray
	
	# get visible symbol count
	symbol_count = PseudoReelIndexes.size()
	
	# set Container size to Reel Size
	container.set_size(Vector2(container.get_rect().size.x, get_rect().size.y))
	
	for index in range(PseudoReelIndexes.size() - offscreen_symbol_count, PseudoReelIndexes.size()):
		var symbol = symbol_prefab.instance()
		container.add_child(symbol)
		symbols.push_back(symbol)
		symbol.emit_signal("update_symbol", symbolDatas[PseudoReelIndexes[index]])
	
	for index in PseudoReelIndexes.size():
		var symbol = symbol_prefab.instance()
		container.add_child(symbol)
		symbols.push_back(symbol)
		symbol.emit_signal("update_symbol", symbolDatas[PseudoReelIndexes[index]])
	
	for index in offscreen_symbol_count:
		var symbol = symbol_prefab.instance()
		container.add_child(symbol)
		symbols.push_back(symbol)
		symbol.emit_signal("update_symbol", symbolDatas[PseudoReelIndexes[index]])
	
#	container.add_constant_override("separation", symbol_offset)
	yield(get_tree(), "idle_frame")
	
	# Make Symbol Adjustments
#	for child in container.get_children():
#		child.size_flags_horizontal -= TextureRect.SIZE_FILL
#		child.size_flags_vertical -= TextureRect.SIZE_FILL
#		child.expand = true
		
#	container.set_size(Vector2(container.get_rect().size.x, get_rect().size.y))
#	yield(get_tree(), "idle_frame")
		
	for child in container.get_children():
		child.rect_min_size = Vector2(symbol_size, symbol_size)
		
	yield(get_tree(), "idle_frame")
	container.add_constant_override("separation", symbol_offset)
	
	stop_index = 1
	
	reelCreated = true # Update reelCreated Flag to receive other commands
	
	set_scroll_position(1) # Set the reel_position to its starting position.
	for symbolIndex in symbols.size(): ## Hides non-visible symbols
		if symbolIndex < stop_index + offscreen_symbol_count - 1 or symbolIndex >= stop_index + screen_symbol_count + offscreen_symbol_count - 1:
			symbols[symbolIndex].emit_signal("hide_symbol")
	self.rect_clip_content = false

## Starts reels spinning and updates reel_status
func startSpin(speed: float):
	if !is_ready(): # Prevent spinning on other states
		return
	is_anticipation = false
	
	## Set Visibility of Contained Symbols
	self.rect_clip_content = true
	emit_to_symbols("show_symbol")
	emit_to_symbols("set_z_order", baseZOrder)
	
	## Set Symbol Orders to Default as it starts spinning
	updateSymbolOrders()
	
	spin_speed = speed
	reelMovementTween = create_tween().set_speed_scale(animationSpeed)
	reelMovementTween.tween_property(self, "scroll_position", -1, startSpeed).as_relative().set_trans(startTransition).set_ease(startEase)
	reelMovementTween.connect("finished", self, "startInfiniteSpin")
	emit_to_symbols("stop_symbol_animation")
	reel_state = Enumerations.REELSTATE.SPINNING

## Emit the given signal on all symbols of this reel
## Can pass only 1 argument
func emit_to_symbols(signal_name : String, arg1 = null, arg2 = null):
	for symbol in symbols:
		if arg1 == null:
			symbol.emit_signal(signal_name)
		elif arg2 == null:
			symbol.emit_signal(signal_name, arg1)
		else:
			symbol.emit_signal(signal_name, arg1, arg2)

## Keep spinning until stop requested
func startInfiniteSpin():
	reelMovementTween = create_tween().set_loops(INF).set_speed_scale(animationSpeed)
	reelMovementTween.tween_property(self, "scroll_position", -1, 1 / spin_speed).as_relative()
	# Blur the Symbols
	emit_to_symbols("set_blur", true)

func startAnticipationSpin():
	if reel_state != Enumerations.REELSTATE.SPINNING:
		return
	
	if reelMovementTween:
		reelMovementTween.kill() # Stop Endless Spin Tween
	
	reelMovementTween = create_tween().set_loops(INF).set_speed_scale(animationSpeed)
	reelMovementTween.tween_property(self, "scroll_position", -1, 1 / spin_speed_anticipation).as_relative()
	# Blur the Symbols
	emit_to_symbols("set_blur", false)
	is_anticipation = true

## Starts the stopping sequence and adjust resulting symbols
func stopSpin(symbolIndexes:Array):
	if reel_state != Enumerations.REELSTATE.SPINNING || reel_state == Enumerations.REELSTATE.STOPPED: # Prevent stopping if not spinning
		return
		
	is_stop_requested = true
	
	if symbolIndexes:
		resolveResultSymbols(symbolIndexes)
	
	if reelMovementTween:
		reelMovementTween.kill() # Stop Endless Spin Tween
	reelMovementTween = create_tween().set_loops(1) #.set_speed_scale(animationSpeed) # Create a tween until it reaches the first symbols
	
	# Get relative distance from current scroll position to stop index
	var relativeIndex
	if stop_index > scroll_position: # cycling situation
		relativeIndex =  -scroll_position -(symbol_count - stop_index)
	else:
		relativeIndex =  stop_index - scroll_position
	
	if is_anticipation:
		reelMovementTween.tween_property(self, "scroll_position", relativeIndex + 0.5, abs(relativeIndex / spin_speed_anticipation)).as_relative()
	else:
		reelMovementTween.tween_property(self, "scroll_position", relativeIndex + 0.5, abs(relativeIndex / spin_speed)).as_relative()
#	reelMovementTween.connect("step_finished", self, "onReelStopping")
	reelMovementTween.tween_property(self, "scroll_position", -0.5, stopSpeed).as_relative().set_trans(stopTransition).set_ease(stopEase)
	reelMovementTween.parallel().tween_callback(self, "emit_to_symbols", ["set_blur", false])
	reelMovementTween.parallel().tween_callback(self, "onReelStopping", [])
#	reelMovementTween.parallel().tween_property(self, "reel_state", Enumerations.REELSTATE.STOPPING, 0)
	reelMovementTween.connect("finished", self, "onReelStopped")

## Skip Spin Animation and shows desired results by mimicing spin ending tween 
func skipSpin(symbolIndexes:Array):
	if reel_state != Enumerations.REELSTATE.SPINNING || reel_state == Enumerations.REELSTATE.STOPPED: # Prevent stopping if not spinning
		return
	if symbolIndexes:
		resolveResultSymbols(symbolIndexes)
		
	is_stop_requested = true
	
	if reelMovementTween:
		reelMovementTween.kill()
	# Set Stopping Tween
	reelMovementTween = create_tween().set_loops(1).set_speed_scale(animationSpeed)
	scroll_position = stop_index + 0.5
	reelMovementTween.tween_property(self,"scroll_position", stop_index, stopSpeed).set_trans(stopTransition).set_ease(stopEase)
	reelMovementTween.parallel().tween_callback(self,"emit_to_symbols", ["set_blur", false])
#		reelMovementTween.tween_callback(self, "onReelStopped")
#		reelMovementTween.connect("finished", self, "onReelStopped")
	onReelStopping()
	reelMovementTween.tween_callback(self, "onReelStopped", [])

## If the reel is stopped, emits on_reel_stopped and updates the state to READY
func onReelStopped():
	reel_state = Enumerations.REELSTATE.READY
	for symbolIndex in symbols.size(): ## Hides non-visible symbols
		if symbolIndex < stop_index + offscreen_symbol_count - 1 or symbolIndex >= stop_index + screen_symbol_count + offscreen_symbol_count - 1:
			symbols[symbolIndex].emit_signal("hide_symbol")
	self.rect_clip_content = false
	is_anticipation = false
	is_stop_requested = false

	emit_signal("on_reel_stopped")
#	emit_to_symbols("play_symbol_animation", "anim")

## Modify the animationSpeed value
## It effects the spin and stop tweens speed scales
func setAnimationSpeed(value: float):
	animationSpeed = value
	if reelMovementTween:
		reelMovementTween.set_speed_scale(value)

## Remove any applied tints on symbols with given indexes
## Also handles the same for repeating symbols
## Highlight every symbol if the input is empty
func onHighlightSymbols(symbolIndexes = []):
	if symbolIndexes.size() == 0:
		emit_to_symbols("remove_tint", tintDuration)
	for index in symbolIndexes:
		symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("remove_tint", tintDuration)
#		print(str(getScreenIndex(index) + offscreen_symbol_count))
		# Also highlight looping symbols
		if symbol_count - getScreenIndex(index) < offscreen_symbol_count:
			symbols[offscreen_symbol_count - (symbol_count - getScreenIndex(index))].emit_signal("remove_tint", tintDuration)
		elif getScreenIndex(index) - offscreen_symbol_count < 0:
			symbols[offscreen_symbol_count + getScreenIndex(index) + symbol_count].emit_signal("remove_tint", tintDuration)

## Animates symbols with given indexes
## Also removes any tinting on animating symbols
## Animate all symbols if the index is empty
func onAnimateSymbols(symbolIndexes = [], animationName = ""):
	if symbolIndexes.size() == 0:
		emit_to_symbols("remove_tint", tintDuration)
		emit_to_symbols("play_symbol_animation", animationName)
	for index in symbolIndexes:
		if index != null: 
			symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("remove_tint", tintDuration)
			symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("play_symbol_animation", animationName)
			
			# Also highlight looping symbols
			if symbol_count - getScreenIndex(index) < offscreen_symbol_count:
				symbols[offscreen_symbol_count - (symbol_count - getScreenIndex(index))].emit_signal("remove_tint", tintDuration)
				symbols[offscreen_symbol_count - (symbol_count - getScreenIndex(index))].emit_signal("play_symbol_animation", animationName)
			elif getScreenIndex(index) - offscreen_symbol_count < 0:
				symbols[offscreen_symbol_count + getScreenIndex(index) + symbol_count].emit_signal("remove_tint", tintDuration)
				symbols[offscreen_symbol_count + getScreenIndex(index) + symbol_count].emit_signal("play_symbol_animation", animationName)


## Apply tints on symbols with given indexes
## Also handles the same for repeating symbols
## Apply tints to every symbol if the input is empty
func onBlackoutSymbols(symbolIndexes = []):
	if symbolIndexes.size() == 0:
		emit_to_symbols("set_tint", dark_color, tintDuration)
		emit_to_symbols("stop_symbol_animation")
	for index in symbolIndexes:
		symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("set_tint", dark_color, tintDuration)
		symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("stop_symbol_animation")
		
		# Also blackout looping symbols
		if symbol_count - getScreenIndex(index)  < offscreen_symbol_count:
			symbols[offscreen_symbol_count - 1 - (symbol_count - getScreenIndex(index) )].emit_signal("set_tint", dark_color, tintDuration)
			symbols[offscreen_symbol_count - 1 - (symbol_count - getScreenIndex(index) )].emit_signal("stop_symbol_animation")
		elif getScreenIndex(index)  - offscreen_symbol_count < 0:
			symbols[offscreen_symbol_count + getScreenIndex(index)  + symbol_count].emit_signal("set_tint", dark_color, tintDuration)
			symbols[offscreen_symbol_count + getScreenIndex(index)  + symbol_count].emit_signal("stop_symbol_animation")

## Frame Oriented Functions

## Add new frame with given framePath visual
## Assign the name to corresponding frame for later usage
func addFrame(name: String, framePath: String):
	if frames.has(name):
		printerr("Frame "+ name + " is existing. Skipping...")
	var frame = TextureRect.new()
	add_child(frame)
	frame.name = name
	frame.texture = load(framePath)
	frame.expand = true
	frame.anchor_right = 1
	frame.anchor_bottom = 1
	frame.margin_bottom = 0
	frame.margin_right = 0
	frame.margin_left = 0
	frame.margin_top = 0
	VisualServer.canvas_item_set_z_as_relative_to_parent(frame.get_canvas_item(), false)
	VisualServer.canvas_item_set_z_index(frame.get_canvas_item(), baseZOrder + symbols.size() + 1)
	frames[name] = frame
	
## Shows the frame with the assigned name
## Returns error if no frame with such name
func showFrame(name: String):
	if frames.has(name) and frames[name]:
		frames[name].show()
		return
	# frame has error
	printerr("Frame " + name + " not found!")
	
## Hides the frame with the assigned name
## Returns error if no frame with such name
func hideFrame(name: String):
	if frames.has(name) and frames[name]:
		frames[name].hide()
		return
	# frame has error
	printerr("Frame " + name + " not found!")

## Hides all frames
func hideAllFrames():
	for frame in frames:
		frame.hide()

## Set view order of the symbol at given index.
## 0 index represents the Top Symbol of the reel
## Reset Symbols to default values on empty call
func updateSymbolOrders(orders:Array = []):
	if orders.size() == 0:
#		print("Adjusting Default Order")
		for index in screen_symbol_count:
			symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("set_z_order", screen_symbol_count - index - 1 + baseZOrder)
	for index in orders.size():
		symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("set_z_order", orders[index] + index + baseZOrder)

## Override the default view order by the given values
func bringSymbolForward(symbolIndex: int, value: int):
	
#	symbols[getScreenIndex(index) + offscreen_symbol_count].emit_signal("remove_tint")
	symbols[getScreenIndex(symbolIndex) + offscreen_symbol_count].emit_signal("set_z_order", value + screen_symbol_count - symbolIndex - 1 + baseZOrder)
	
	# Also highlight looping symbols
	if symbol_count - getScreenIndex(symbolIndex) < offscreen_symbol_count:
		symbols[offscreen_symbol_count - (symbol_count - getScreenIndex(symbolIndex))].emit_signal("remove_tint")
		symbols[offscreen_symbol_count - (symbol_count - getScreenIndex(symbolIndex))].emit_signal("set_z_order", value + screen_symbol_count - symbolIndex - 1 + baseZOrder)
	elif getScreenIndex(symbolIndex) - offscreen_symbol_count < 0:
		symbols[offscreen_symbol_count + getScreenIndex(symbolIndex) + symbol_count].emit_signal("remove_tint")
		symbols[offscreen_symbol_count + getScreenIndex(symbolIndex) + symbol_count].emit_signal("set_z_order", value + screen_symbol_count - symbolIndex - 1 + baseZOrder)

func updateSymbolData(symbolIndex: int, symbolData: SymbolData):
	symbols[offscreen_symbol_count + getScreenIndex(symbolIndex)].emit_signal("update_symbol", symbolData)
	
	if symbol_count - getScreenIndex(symbolIndex) < offscreen_symbol_count:
		symbols[offscreen_symbol_count - (symbol_count - getScreenIndex(symbolIndex))].emit_signal("update_symbol", symbolData)
	if getScreenIndex(symbolIndex) - offscreen_symbol_count < 0:
		symbols[offscreen_symbol_count + getScreenIndex(symbolIndex) + symbol_count].emit_signal("update_symbol", symbolData)
	
# HELPER FUNCTIONS
#####################################

## Updates symbol visuals at the result indexes
func resolveResultSymbols(symbolArray) -> int:
	updateSymbolOrders() # Set shown symbol z-orders to their default values
	stop_index = get_scroll_position(int(scroll_position) - screen_symbol_count - 1)  ## Adjust stop position of results first symbol
	for index in symbolArray.size():
		container.get_child(getScreenIndex(index)+offscreen_symbol_count).emit_signal("update_symbol", symbolDatas[symbolArray[index]])
		if symbol_count - getScreenIndex(index) < offscreen_symbol_count:
			container.get_child(offscreen_symbol_count - (symbol_count - getScreenIndex(index))).emit_signal("update_symbol", symbolDatas[symbolArray[index]])
		elif getScreenIndex(index) - offscreen_symbol_count < 0:
			container.get_child(offscreen_symbol_count + getScreenIndex(index) + symbol_count).emit_signal("update_symbol", symbolDatas[symbolArray[index]])
	return stop_index

## Setter for scroll_position variable.
## It shifts the amount of symbol count to create a looping effect.
func set_scroll_position(value):
	scroll_position = value
	if not reelCreated:
		return
	if  scroll_position > symbol_count:
		scroll_position -= symbol_count
	elif scroll_position < 0:
		scroll_position += symbol_count
	container.set_position(Vector2.UP * (scroll_position + offscreen_symbol_count - 1) * (symbol_size + symbol_offset))
	if !is_stop_requested:
		if last_position_change != int(scroll_position):
			last_position_change = int(scroll_position)
			var nextPseudoSymbolIndex = pseudoReelIndexes[last_position_change % pseudoReelIndexes.size()] 
			
			container.get_child(getDynamicScreenIndex(screen_symbol_count + 1)+offscreen_symbol_count).SymbolImage.texture = symbolDatas[nextPseudoSymbolIndex].image_static
			container.get_child(getDynamicScreenIndex(screen_symbol_count + 1)+offscreen_symbol_count).SymbolImage_Blur.texture = symbolDatas[nextPseudoSymbolIndex].image_blur
			if symbol_count - getDynamicScreenIndex(screen_symbol_count + 1) < offscreen_symbol_count:
				container.get_child(offscreen_symbol_count - (symbol_count - getDynamicScreenIndex(screen_symbol_count + 1))).SymbolImage.texture = symbolDatas[nextPseudoSymbolIndex].image_static
				container.get_child(offscreen_symbol_count - (symbol_count - getDynamicScreenIndex(screen_symbol_count + 1))).SymbolImage_Blur.texture = symbolDatas[nextPseudoSymbolIndex].image_blur
			elif getDynamicScreenIndex(screen_symbol_count + 1) - offscreen_symbol_count < 0:
				container.get_child(offscreen_symbol_count + getDynamicScreenIndex(screen_symbol_count + 1) + symbol_count).SymbolImage.texture = symbolDatas[nextPseudoSymbolIndex].image_static
				container.get_child(offscreen_symbol_count + getDynamicScreenIndex(screen_symbol_count + 1) + symbol_count).SymbolImage_Blur.texture = symbolDatas[nextPseudoSymbolIndex].image_blur

func get_scroll_position(value) -> int:
	if not reelCreated:
		printerr("Reel is not created yet")
		return value
	if value > symbol_count:
		return get_scroll_position(value - symbol_count)
	elif value < 0:
		return get_scroll_position(value + symbol_count)
	return value

## It returns true if the reel state is READY
func is_ready() -> bool:
	return reel_state == Enumerations.REELSTATE.READY

## Change the reel status to STOPPED
func onReelStopping(): 
	reel_state = Enumerations.REELSTATE.STOPPED
	updateSymbolOrders()
	emit_signal("on_reel_stopping")
	pass

## Returns reel status
func getReelStatus() ->bool:
	return reel_state

## Returns scroll index of given index according to stop_index
func getScreenIndex(index: int) -> int:
	return get_scroll_position(stop_index + index)-1

# Returns symbol with given index according to stop_index
func getScreenSymbol(index: int) -> Symbol:
	if index == screen_symbol_count - 1 && getScreenIndex(index) == 0: # Repeating Symbol Fix
		return symbols[offscreen_symbol_count + symbol_count]
		
	return symbols[getScreenIndex(index) + offscreen_symbol_count]

func getDynamicScreenIndex(index: int) -> int:
	return get_scroll_position(scroll_position + index)-1

func getDynamicScreenSymbol(index:int) -> Symbol:
	if index == screen_symbol_count - 1 && getDynamicScreenIndex(index) == 0: # Repeating Symbol Fix
		return symbols[offscreen_symbol_count + symbol_count]
		
	return symbols[getDynamicScreenIndex(index) + offscreen_symbol_count]


# DEBUG VARIABLES
# Used for Debugging and Testing the scene seperately.
#####################################
# Demo Symbol Visual Path
export(Array,Resource) var debug_reelSymbols = []

# Demo Pseudo Reels
var debug_pseudoReel = [
		0,1,2,3,4,5,0,1,2,3,4,5
		]
