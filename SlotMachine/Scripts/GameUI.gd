class_name GameUI
extends Control

# button signals
signal on_button_pressed
signal on_spin_pressed
signal on_spin_released
signal on_stop_pressed
signal on_stop_released
signal on_bet_increase_pressed
signal on_bet_decrease_pressed
signal on_audio_toggled
signal on_quickspin_toggled
signal on_menu_pressed
signal on_autoplay_pressed
signal on_confirm_autoplay_pressed
signal on_autoplay_stop_on_bonus_toggled
signal on_autoplay_quickspin_toggled
signal on_remaining_round_updated
signal on_info_pressed
signal on_paytable_pressed
signal on_history_pressed
signal on_home_pressed
signal set_quickspin_toggle
signal set_audio_toggle
signal set_spin_button
signal set_autoplay_stop_on_bonus
signal set_autoplay_round
signal set_autoplay_remaining_round
signal set_autoplay_is_playing
signal disable_menu
signal enable_menu
signal disable_bets
signal enable_bets
signal disable_autoplay
signal enable_autoplay

# text signals
signal on_main_message_updated
signal on_win_message_updated
signal on_secondary_message_updated
signal update_message
signal on_balance_updated
signal on_bet_amount_updated
signal set_currency_symbol

export(Color) var active_button_color: Color
export(Color) var disabled_button_color: Color

export(NodePath) var canvas_layer_path; onready var canvas_layer := get_node(canvas_layer_path) as CanvasLayer

# text components
export(NodePath) var text_balance_amount_path; onready var text_balance_amount := get_node(text_balance_amount_path) as Label
export(NodePath) var text_bet_amount_path; onready var text_bet_amount := get_node(text_bet_amount_path) as Label
export(NodePath) var text_main_message_path; onready var text_main_message := get_node(text_main_message_path) as RichTextLabel
export(NodePath) var text_secondary_message_path; onready var text_secondary_message := get_node(text_secondary_message_path) as Label

# symbol message components
export(NodePath) var text_secondary_message_with_symbol_path; onready var text_secondary_message_with_symbol := get_node(text_secondary_message_with_symbol_path) as Control
export(NodePath) var text_secondary_message_pre_symbol_path; onready var text_secondary_message_pre_symbol := get_node(text_secondary_message_pre_symbol_path) as Label
export(NodePath) var text_secondary_message_symbol_path; onready var text_secondary_message_symbol := get_node(text_secondary_message_symbol_path) as TextureRect
export(NodePath) var text_secondary_message_post_symbol_path; onready var text_secondary_message_post_symbol := get_node(text_secondary_message_post_symbol_path) as Label

# button components
export(NodePath) var button_menu_path; onready var button_menu := get_node(button_menu_path) as Button
export(NodePath) var button_bet_increase_path; onready var button_bet_increase := get_node(button_bet_increase_path) as Button
export(NodePath) var button_bet_decrease_path; onready var button_bet_decrease := get_node(button_bet_decrease_path) as Button
export(NodePath) var button_spin_path; onready var button_spin := get_node(button_spin_path) as Button
export(NodePath) var button_stop_path; onready var button_stop := get_node(button_stop_path) as Button
export(NodePath) var button_spin_autoplay_path; onready var button_spin_autoplay := get_node(button_spin_autoplay_path) as Button
export(NodePath) var button_autoplay_path; onready var button_autoplay := get_node(button_autoplay_path) as Button
export(NodePath) var toggle_audio_path; onready var toggle_audio := get_node(toggle_audio_path) as Button
export(NodePath) var toggle_quickspin_path; onready var toggle_quickspin := get_node(toggle_quickspin_path) as Button
export(NodePath) var icon_quickspin_path; onready var icon_quickspin := get_node(icon_quickspin_path) as TextureRect
export(NodePath) var icon_audio_on_path; onready var icon_audio_on := get_node(icon_audio_on_path) as TextureRect
export(NodePath) var icon_audio_off_path; onready var icon_audio_off := get_node(icon_audio_off_path) as TextureRect

export(Font) var message_font_default;
export(Font) var message_font_big;

# Count Related Values for Win and Balance Tweens
## Defines Counting Transition Curve
export (int,"TRANS_LINEAR", "TRANS_SINE", "TRANS_QUINT",
		"TRANS_QUART", "TRANS_QUAD", "TRANS_EXPO", "TRANS_ELASTIC",
		"TRANS_CUBIC","TRANS_CIRC", "TRANS_BOUNCE", "TRANS_BACK") var text_count_transition: int = 0
## Defines Counting Ease Type
export (int, "EASE_IN", "EASE_OUT", "EASE_IN_OUT", "EASE_OUT_IN") var text_count_ease: int = 2
export (float) var text_count_duration = 1.0

var zorder_for_autoplay_panel = 0
var burgerTween: SceneTreeTween
var isBurgerOpen: bool = false
var totalWinTextTween: SceneTreeTween
var balanceTextTween: SceneTreeTween

# UI Properties
var decimalSeperator: String = ","
var integerSeperator: String = "."
var isCurrencySymbolFirst: bool = false
var currencySymbol: String = "€"
var betAmount: float = 0
var balanceAmount: float = 0

func _ready(): 
	# Place default values on texts
	text_balance_amount.text = ""
	text_bet_amount.text = ""
	text_main_message.text = ""
	text_secondary_message.text = ""
	
	# Setup HUD Components and Signals
	setupTextSignals()
	setupButtonSignals()
	
	setCurrencySymbol("€")
	updateSecondaryMessage("")
	
# Text Field Signal Connections
func setupTextSignals():
	self.connect("on_balance_updated", self, "updateBalanceAmount")
	self.connect("on_bet_amount_updated", self, "updateBetAmount")
	self.connect("on_main_message_updated", self, "updateMainMessage")
	self.connect("on_secondary_message_updated", self, "updateSecondaryMessage")
	self.connect("on_win_message_updated", self, "updateWinMessage")
	self.connect("update_message", self, "updateMessage")
	self.connect("set_currency_symbol", self, "setCurrencySymbol")

func onResize():
	text_main_message.rect_pivot_offset.x = text_main_message.rect_size.x/2
	updateMainMessageScale()

func updateBetAmount(value:float):
	if betAmount == value:
		return
	betAmount = value
	text_bet_amount.text = formatCurrencyText(value, currencySymbol)
	self.emit_signal("on_button_pressed")

func updateBalanceAmount(value:float, isAnimated = false):
	if balanceTextTween:
		balanceTextTween.custom_step(text_count_duration)
		balanceTextTween.kill()
	if isAnimated:
		balanceTextTween = create_tween().set_trans(text_count_transition).set_ease(text_count_ease)
		balanceTextTween.tween_method(self, "setBalanceText", balanceAmount * 100, value * 100, text_count_duration)
	else:
		text_balance_amount.text = formatCurrencyText(value, currencySymbol) #formatCurrencyText(value, currency)
	
	balanceAmount = value

func setBalanceText(value: float):
	text_balance_amount.text = formatCurrencyText(value / 100, currencySymbol) #formatCurrencyText(value, currency)

func updateMainMessage(message:String):
	if totalWinTextTween:
		totalWinTextTween.kill()
	text_main_message.bbcode_text = "[center]%s[/center]" % message.to_upper()
	updateMainMessageScale()

func updateSecondaryMessage(message:String):
	if message != "":
		text_secondary_message.show()
		if message.find("[img]") >= 0:
			text_secondary_message.text = ""
			var messageParts = message.split("[img]")
			text_secondary_message_pre_symbol.text = messageParts[0]
			text_secondary_message_symbol.texture = load(messageParts[1])
			text_secondary_message_post_symbol.text = messageParts[2]
			text_secondary_message_with_symbol.show()
		else:
			text_secondary_message.text = "%s" % message
			text_secondary_message_with_symbol.hide()
	else:
		text_secondary_message.hide()
		text_secondary_message.text = ""
	updateMainMessageScale()

func updateMainMessageScale():
	if !text_secondary_message.visible:
		text_main_message.add_font_override("normal_font", message_font_big)
	else:
		text_main_message.add_font_override("normal_font", message_font_default)

func updateMessage(mainMessage:String = "", secondaryMessage:String = ""):
#	print("Message Updated with\n" + mainMessage + "\n" + secondaryMessage)
	updateMainMessage(mainMessage)
	updateSecondaryMessage(secondaryMessage)

func updateWinMessage(winAmount: float, winMessage: String, startingWinAmount:float = 0):
	if totalWinTextTween:
		totalWinTextTween.custom_step(text_count_duration)
		totalWinTextTween.kill()
	totalWinTextTween = create_tween().set_trans(text_count_transition).set_ease(text_count_ease)
	totalWinTextTween.tween_method(self, "tweenTextMessage", startingWinAmount * 100.0, winAmount * 100.0, text_count_duration, [text_main_message, winMessage])
	totalWinTextTween.tween_callback(self, "updateMainMessageScale")

func tweenTextMessage(value, targetText, messageText = ""):
	if targetText is RichTextLabel:
		if messageText == "":
			targetText.bbcode_text = "%.2f" % (value / 100)
		else:
			targetText.bbcode_text = tr(messageText) % formatCurrencyText(value / 100, currencySymbol)
	elif targetText is Label:
		if messageText == "":
			targetText.text = "%.2f" % (value / 100)
		else:
			targetText.text = tr(messageText) % (value / 100)
			print("value: %.0f" % value)

# Button Signal Connections
func setupButtonSignals() -> void:
	button_bet_increase.connect("pressed", self, "onIncreaseBetButtonPressed")
	button_bet_decrease.connect("pressed", self, "onDecreaseBetButtonPressed")
	
	button_bet_increase.connect("button_up", self, "onIncreaseBetButtonReleased")
	button_bet_decrease.connect("button_up", self, "onDecreaseBetButtonReleased")
	
	button_autoplay.connect("pressed", self, "onAutoplayButtonPressed")
	
	toggle_audio.connect("pressed", self, "onAudioButtonPressed")
	toggle_audio.disabled = true
	
	toggle_quickspin.connect("pressed", self, "onQuickspinButtonPressed")
	
	button_spin.connect("button_down", self, "onSpinButtonPressed")
	button_stop.connect("button_down", self, "onStopButtonPressed")
	button_spin_autoplay.connect("button_down", self, "onSpinButtonPressed")
	button_spin_autoplay.connect("button_down", self, "onStopButtonPressed")

	disableAutoplay()
	disableMenuButtons()
	
	connect("set_quickspin_toggle", self, "onQuickspinUpdated")
	connect("set_audio_toggle", self, "onAudioUpdated")
	
	connect("set_spin_button", self, "onPlayButtonSet")
	
	connect("disable_menu", self, "disableMenuButtons")
	connect("enable_menu", self, "enableMenuButtons")
	connect("disable_bets", self, "disableBetButtons")
	connect("enable_bets", self, "enableBetButtons")
	connect("disable_autoplay", self, "disableAutoplay")
	connect("enable_autoplay", self, "enableAutoplay")
	connect("set_autoplay_is_playing", self, "setAutoplayIsPlaying")

func onMenuButtonPressed():
	self.emit_signal("on_button_pressed")

func onMobileMenuButtonPressed():
	self.emit_signal("on_menu_pressed", betAmount)
	self.emit_signal("on_button_pressed")

func onInfoButtonPressed():
	closeBurgerMenu()
	self.emit_signal("on_info_pressed", betAmount)
	self.emit_signal("on_button_pressed")

func onPaytableButtonPressed():
	closeBurgerMenu()
	self.emit_signal("on_paytable_pressed", betAmount)
	self.emit_signal("on_button_pressed")

func onHistoryButtonPressed():
	closeBurgerMenu()
	self.emit_signal("on_history_pressed", betAmount)
	self.emit_signal("on_button_pressed")

func onHomeButtonPressed():
	self.emit_signal("on_home_pressed")
	self.emit_signal("on_button_pressed")

func onAutoplayButtonPressed():
	closeBurgerMenu()
	self.emit_signal("on_autoplay_pressed")
	self.emit_signal("on_button_pressed")

func onAudioButtonPressed():
	closeBurgerMenu()
	self.emit_signal("on_audio_toggled")
	self.emit_signal("on_button_pressed")
	
func onQuickspinButtonPressed():
	self.emit_signal("on_quickspin_toggled")
	self.emit_signal("on_button_pressed")

func onQuickspinUpdated(value:bool):
	icon_quickspin.modulate = active_button_color if value else Color.white

func onAudioUpdated(value:bool):
	icon_audio_on.visible = !value
	icon_audio_off.visible = value

func onSpinButtonPressed():
	closeBurgerMenu()
	self.emit_signal("on_spin_pressed")
	
func onSpinButtonReleased():
	self.emit_signal("on_spin_released")
	
func onStopButtonPressed():
	self.emit_signal("on_stop_pressed")
	
func onStopButtonReleased():
	self.emit_signal("on_stop_released")
	
func onDecreaseBetButtonPressed():
	button_bet_decrease.get_child(0).modulate = active_button_color
	self.emit_signal("on_bet_decrease_pressed")

func onDecreaseBetButtonReleased():
	button_bet_decrease.get_child(0).modulate = Color.white

func onIncreaseBetButtonPressed():
	button_bet_increase.get_child(0).modulate = active_button_color
	self.emit_signal("on_bet_increase_pressed")

func onIncreaseBetButtonReleased():
	button_bet_increase.get_child(0).modulate = Color.white

func onBalancePanelHide():
	text_balance_amount.get_parent().hide()

func onPlayButtonSet(buttonType, isDisabled = false):
	
	# Enable/Disable Buttons
	set_disable(button_spin, isDisabled or buttonType != Enumerations.SPINBUTTONTYPE.SPIN)
	set_disable(button_stop, isDisabled or buttonType != Enumerations.SPINBUTTONTYPE.STOP)
	set_disable(button_spin_autoplay, isDisabled or buttonType != Enumerations.SPINBUTTONTYPE.AUTOPLAY)
	
	# Set Button Visibility
	button_spin.visible = buttonType == Enumerations.SPINBUTTONTYPE.SPIN
	button_stop.visible = buttonType == Enumerations.SPINBUTTONTYPE.STOP
	button_spin_autoplay.visible = buttonType == Enumerations.SPINBUTTONTYPE.AUTOPLAY

func set_disable(button, value:bool):
	button.disabled = value
	button.get_child(0).modulate = disabled_button_color if value else Color.white

func openBurgerMenu():
	pass

func closeBurgerMenu():
	pass

func disableBetButtons():
	button_bet_increase.disabled = true
	button_bet_increase.modulate.a = .6
	button_bet_decrease.disabled = true
	button_bet_decrease.modulate.a = .6

func enableBetButtons():
	button_bet_increase.disabled = false
	button_bet_increase.modulate.a = 1
	button_bet_decrease.disabled = false
	button_bet_decrease.modulate.a = 1

func disableMenuButtons():
	button_menu.disabled = true
	button_menu.modulate.a = .6
	closeBurgerMenu()

func enableMenuButtons():
	button_menu.disabled = false
	button_menu.modulate.a = 1

func disableAutoplay():
	button_autoplay.disabled = true
	button_autoplay.modulate.a = .6

func enableAutoplay():
	button_autoplay.disabled = false
	button_autoplay.modulate.a = 1

func setCurrencySymbol(currency: String, localizationInfo: LocalizationInfo = null):
	if localizationInfo:
		decimalSeperator = localizationInfo.decimalSeperator
		integerSeperator = localizationInfo.integerSeperator
		isCurrencySymbolFirst = localizationInfo.isCurrencySymbolFirst
	currencySymbol =  currency
	
	updateBetAmount(betAmount)
	updateBalanceAmount(balanceAmount)

func formatCurrencyText(value: float, currency: String) -> String:
	if value < 0:
		value = 0
	# Convert the float to a string and
	# split the string into the integer and decimal parts
	var parts = ("%.2f" % value).split(".")
	
	## parts[0] - Integer Part
	## parts[1] - Decimal Part
	
	# Add thousand separators to the integer part
	var result = ""
	var count = 0
	for i in range(parts[0].length() - 1, -1, -1):
		result = parts[0][i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = integerSeperator + result

	# Combine the integer part and the decimal part
	result += decimalSeperator + parts[1]
	
	if isCurrencySymbolFirst:
		return "%s%s" % [currency, result]
	else:
		return "%s %s" % [result, currency]
