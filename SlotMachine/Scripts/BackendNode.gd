class_name BackendNode
extends Node

## This Class is responsible for
## - Handling Round Requests
## - Prevent Multiple or Wrong Requests
## - Parse Server Result
## - Convert Result to SpinResult
##
## == Created for Topgaming Ltd. 2024 by Semih Bertug Benim ==

# SIGNALS
#####################################

signal connection_request
signal spin_requested
signal save_preferences_requested
signal language_requested
signal adjust_bet_index
signal update_bet_index
signal connection_established
signal server_error
signal spin_result_ready
signal language_received
signal game_info_received
signal bet_index_updated
signal replay_data_received

# CONSTANTS
#####################################

# PRIVATE VARIABLES
#####################################

var is_spin_inprogress: bool
var result: SpinResult
var previous_result: SpinResult
var sessionId: String
var current_game_mode: int # Enumerations.GAMESTATE

var balance: float
var balance_before_spin: float
var betAmounts: Array = [10.0, 20.0, 50.0, 75.0, 100.0, 200.0, 500.0, 1000.0]
var currentBetIndex: int = 0
var currentRound: String

# SIGNAL FUNCTIONS
#####################################

func onConnectionRequest():
	print("Connecting to Server...")

func onConnectionEstablished():
	emit_signal("connection_established", getPlayerData())

func onGameSpinRequest():
	if is_spin_inprogress: # Do nothing if the request is ongoing...
		return
	balance_before_spin = balance

func onRoundReceived(data: Dictionary):
	previous_result = result
	createDefaultResult(data)
	balance = result.balance
	is_spin_inprogress = false
	emit_signal("spin_result_ready", result)

func adjustBetIndex(indexChange:int):
	var newIndex = currentBetIndex + indexChange
	updateBetIndex(newIndex)

func updateBetIndex(newIndex: int):
	setBetIndex(newIndex)
	emit_signal("bet_index_updated", betAmounts[currentBetIndex])

func setBetIndex(newIndex: int):
	if newIndex >= betAmounts.size():
		newIndex = betAmounts.size() -1
	if newIndex < 0:
		newIndex = 0
	if betAmounts[newIndex] >= balance:
		newIndex = returnMaxBet()
	currentBetIndex = newIndex

func onBetIndexAdjust():
	pass

# HELPER FUNCTIONS
#####################################

func createDefaultResult(data: Dictionary = {}):
	pass

func getGameData():
	return {}

func getPlayerData():
	return {}

func returnMaxBet() -> int :
	var index = betAmounts.size() - 1
	while index > 0:
		if balance > betAmounts[index]:
			return index
		index -= 1
	return 0
