class_name Symbol
extends Control

# SIGNALS
#####################################

signal update_symbol
signal copy_symbol
signal play_symbol_animation
signal stop_symbol_animation
signal animate_frame
signal animate
signal set_tint
signal remove_tint
signal set_blur
signal add_frame
signal show_frame
signal hide_frame
signal hide_all_frames
signal show_symbol
signal hide_symbol
signal setAsPseudoSymbol
signal set_z_order
signal symbol_is_updated

# CONSTANTS
#####################################

# EXPORT VARIABLES 
#####################################
export var symbolData : Resource
export var isUnitTesting : bool = false

# PRIVATE VARIABLES
#####################################

var startSize: float
var startScale: float

var frames : Dictionary
var symbolSize : float

var tintTween : SceneTreeTween

var isPseudoSymbol : bool = false

var defaultAnimationName : String = "anim"

var isUpdating : bool = false

# ONREADY VARIABLES
#####################################

onready var SymbolImage: TextureRect = $SymbolContainer/SymbolImage
onready var SymbolImage_Blur: TextureRect = $SymbolContainer/SymbolImage_Blur
onready var SymbolAnimated: SpineSprite = $SymbolContainer/SymbolImage/SymbolAnimated
onready var SymbolMask : Light2D = $SymbolContainer/SymbolImage/SymbolMask
onready var SymbolContainer = $SymbolContainer

# FUNCTIONS
#####################################

func _ready():
	frames = {} # Create Frame Array
	startSize = SymbolImage.rect_size.x
	startScale = SymbolAnimated.scale.x
	
	# Handle Signals
	connect("update_symbol", self, "setupSymbol")
	connect("copy_symbol", self, "copySymbolData")
	connect("play_symbol_animation", self, "playSymbolAnimation")
	connect("stop_symbol_animation", self, "stopSymbolAnimation")
	connect("animate_frame", self, "animateFrame")
	connect("animate", self, "animateAll")
	connect("set_tint", self, "applyTint")
	connect("remove_tint", self, "removeTint")
	connect("set_blur", self, "setBlur")
	connect("add_frame", self, "addFrame")
	connect("show_frame", self, "showFrame")
	connect("hide_frame", self, "hideFrame")
	connect("hide_all_frames", self, "hideAllFrames")
	connect("resized", self, "onResize")
	connect("show_symbol", SymbolContainer, "show")
	connect("hide_symbol", SymbolContainer, "hide")
	connect("set_z_order", self, "onSetZOrder")
	SymbolAnimated.connect("animation_completed", self, "onSymbolAnimationCompleted")
	
	if isUnitTesting:
		setupSymbol(symbolData)
		runDebug()

# SIGNAL FUNCTIONS
#####################################

export var isBlurred: bool setget setBlur
func setBlur(value):
	isBlurred = value
	SymbolImage_Blur.visible = isBlurred
	SymbolImage.visible = !isBlurred

export var frameExpand: float setget setFrameExpand
func setFrameExpand(value):
	frameExpand = value
	for key in frames:
		frames[key].margin_bottom = frameExpand
		frames[key].margin_right = frameExpand
		frames[key].margin_left = -frameExpand
		frames[key].margin_top = -frameExpand

func setupSymbol(data:SymbolData):
	stopSymbolAnimation()
	SymbolAnimated.self_modulate.a = 0
	isUpdating = true
	symbolData = data
	# Update Visuals of Symbol
	SymbolImage.texture = data.image_static
	SymbolImage_Blur.texture = data.image_blur
	SymbolAnimated.skeleton_data_res = data.animation_data
	SymbolMask.texture = data.image_mask
	defaultAnimationName = data.defaultAnimationName
	yield(get_tree(), "idle_frame")
	isUpdating = false
	emit_signal("symbol_is_updated")

func copySymbolData(otherSymbol: Symbol):
	SymbolImage.texture = otherSymbol.SymbolImage.texture
	SymbolImage_Blur.texture = otherSymbol.SymbolImage_Blur.texture
	SymbolAnimated.skeleton_data_res = otherSymbol.SymbolAnimated.skeleton_data_res
	defaultAnimationName = otherSymbol.defaultAnimationName

func showFrame(name: String):
	if frames.has(name) and frames[name]:
		frames[name].show()
		return
	# frame has error
#	print_debug("Frame " + name + " not found! on symbol " + self.name)

func hideFrame(name: String):
	if frames.has(name) and frames[name]:
		frames[name].hide()
		return
	# frame has error
#	print_debug("Frame " + name + " not found! on symbol " + self.name)

func hideAllFrames():
	for frame in frames.values():
		frame.hide()

func addFrame(name: String, framePath: PackedScene):
	if frames.has(name):
		printerr("Frame "+ name + " is existing. Skipping...")
	var frame = framePath.instance()
	SymbolContainer.add_child(frame)
	frame.name = name
	frames[name] = frame

func applyTint(color:Color, tweenTime: float = 0):
	if tintTween:
		tintTween.kill()
	if tweenTime > 0:
		tintTween = create_tween()
		tintTween.tween_property(SymbolImage, "modulate", color, tweenTime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tintTween.parallel().tween_property(SymbolImage_Blur, "modulate", color, tweenTime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		return
	SymbolImage.modulate = color
	SymbolImage_Blur.modulate = color

func removeTint(tweenTime: float = 0):
	applyTint(Color.white, tweenTime)

func playSymbolAnimation(animationName:String = ""):
	SymbolAnimated.skeleton_data_res = null
	SymbolAnimated.skeleton_data_res = symbolData.animation_data
	SymbolAnimated.get_animation_state().set_animation(animationName if animationName else defaultAnimationName, false, 0)
	SymbolAnimated.show()
	SymbolMask.show()
	SymbolAnimated.self_modulate.a = 1

func stopSymbolAnimation():
	SymbolAnimated.self_modulate.a = 0
	SymbolAnimated.hide()
	
func onSymbolAnimationCompleted(spine_sprite: Object, animation_state: Object, track_entry: Object):
	stopSymbolAnimation()

func animateFrame(frameName:String = "", animationName: String = "default"):
	if frameName == "":
		# play all frame animations
		for key in frames:
#			frames[key].show()
			frames[key].get_animation_state().set_animation(animationName, false, 0)
	elif frames.has(frameName) && frames.get(frameName).get_animation_state():
#		frames[frameName].show()
		frames[frameName].get_animation_state().set_animation(animationName, false, 0)

func stopFrameAnimation(frameName:String = ""):
	if frameName == "":
		# play all frame animations
		for key in frames:
			frames[key].hide()
	elif frames.has(frameName):
		frames[frameName].hide()

func onResize():
	var newScale = startScale * (rect_size.x / startSize)
	SymbolAnimated.scale = Vector2(newScale, newScale)
	SymbolMask.scale = Vector2(newScale, newScale)
	SymbolAnimated.position = Vector2(rect_size.x / 2, rect_size.x / 2)
	SymbolMask.position = Vector2(rect_size.x / 2, rect_size.x / 2)
	for frameName in frames.keys():
		frames[frameName].scale = Vector2(newScale, newScale)
		frames[frameName].position = Vector2(rect_size.x / 2, rect_size.x / 2)

func onSetZOrder(newZValue:int):
#	SymbolAnimated.z_as_relative = true
#	SymbolAnimated.z_index = newZValue
	VisualServer.canvas_item_set_z_as_relative_to_parent(SymbolContainer.get_canvas_item(), false)
	VisualServer.canvas_item_set_z_index(SymbolContainer.get_canvas_item(), newZValue)

# HELPER FUNCTIONS
#####################################


# DEBUG SEQUENCE
#####################################

func runDebug():
#	emit_signal("add_frame",
#			"WinFrame",
#			"res://Visuals/Sprites/Frames/x2-x5.webp")
#	hideAllFrames()

	var testTween = create_tween().set_loops(INF)
	testTween.tween_callback(self, "hideFrame", ["WinFrame"])
	testTween.tween_callback(self, "applyTint", [Color.dimgray, 0.3]).set_delay(1.0)
	testTween.tween_callback(self, "removeTint", [0.3]).set_delay(1.0)
	testTween.tween_property(self, "isBlurred", true, 1).set_delay(1.0)
	testTween.tween_property(self, "isBlurred", false, 1)
	testTween.tween_callback(self, "playSymbolAnimation")
	testTween.tween_callback(self, "stopSymbolAnimation").set_delay(1.0)
	testTween.tween_callback(self, "emit_signal", ["hide_symbol"]).set_delay(1.0)
	testTween.tween_callback(self, "emit_signal", ["show_symbol"]).set_delay(1.0)
	testTween.tween_callback(self, "showFrame", ["WinFrame"])
	testTween.tween_property(self, "frameExpand", 5, .4).set_trans(Tween.TRANS_SINE).set_delay(1)
	testTween.tween_property(self, "frameExpand", 0, .4).set_trans(Tween.TRANS_SINE)
	testTween.tween_property(self, "frameExpand", 5, .4).set_trans(Tween.TRANS_SINE)
	testTween.tween_property(self, "frameExpand", 0, .4).set_trans(Tween.TRANS_SINE)

# END OF DEBUG SEQUENCE


