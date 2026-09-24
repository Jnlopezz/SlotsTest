class_name VirtualBackend
extends BackendNode

signal bonus_selected
signal bonus_game_requested

const results_queue = [
	[[1,1,0],[1,0,2],[1,2,3],[3,3,3],[4,5,4]],
	[[0,5,3],[1,0,2],[2,0,2],[4,5,3],[1,4,4]],
	[[0,2,4],[1,0,1],[2,2,2],[3,3,3],[4,2,4]],
	[[0,3,5],[1,1,1],[2,2,2],[5,4,3],[4,2,5]],
	[[0,3,1],[0,1,1],[0,1,2],[3,5,3],[4,1,4]],
	[[0,0,2],[1,1,1],[2,2,2],[3,0,3],[4,1,4]],
	[[4,0,2],[4,1,1],[4,2,2],[3,0,3],[4,1,4]],
]
var current_result_index = 0

const DEFAULT_GAME_DATA = {
	"playerData":
		{
		"balance":99999, 
		"currency":"EUR", 
		"locale":"it", 
		}, 
	"gameData":
		{
			"bets": [10.0, 20.0, 50.0, 75.0, 100.0, 200.0, 500.0, 1000.0],
		},
	"success":"True"
	}

# Symbol Pay Values as Credits
# 12345 value is used for debugging
const paytable = {
		"55555":5, "66666":5, "77777":5, "88888":5,"99999": 5,
		"00000":2.5, "11111":2.5, "22222":2.5, "33333":2.5,"44444": 2.5,
		"5555":1, "6666":1, "7777":1, "8888":1, "9999": 1,
		"0000":.5, "1111":.5, "2222":.5, "3333":.5, "4444":.5,
		"555":.2, "666":.2, "777":.2, "888":.2,"999":.2,
		"000":.1, "111":.1, "222":.1, "333":.1,"444":.1,
		}

# lines: Each digit shows which row of each column.
# Eg. for 010 value:
# [- -]
# [ - ]
# [   ] 
const lines = [
		[1,1,1,1,1],
		[0,0,0,0,0],
		[2,2,2,2,2],
		[0,1,2,1,0],
		[2,1,0,1,2],
		[0,0,1,0,0],
		[1,2,2,2,1],
		[1,0,0,0,1],
		[2,2,1,2,2],
		[1,0,1,0,1],
		[1,2,1,2,1],
		]

const wildSymbolIndex = 5

onready var pingTimer: Timer = $PingTimer

func _ready():
	connect("connection_request", self, "onConnectionRequest")

func onConnectionRequest():
	print("Connecting to Server...")
	onConnectionEstablished()

func onConnectionEstablished():
	TranslationServer.set_locale(getPlayerData().get("locale"))
	balance = getPlayerData().get("balance", 1000)/100
	
	connect("spin_requested", self, "onGameSpinRequest")
	connect("bonus_game_requested", self, "onBonusGameRequest")
	connect("bonus_selected", self, "onBonusSelected")
	connect("adjust_bet_index", self, "adjustBetIndex")
	connect("update_bet_index", self, "updateBetIndex")
	connect("bonus_selected", self, "onBonusSelect")
	connect("language_requested", self, "onLanguageRequest")
	
	emit_signal("connection_established", getPlayerData())
	current_game_mode = Enumerations.GAMESTATE.DEFAULT
	

func onGameSpinRequest():
#	print("Request Received")
	if is_spin_inprogress: # Do nothing if the request is ongoing...
#		print("Spin in progress...")
		return
	if balance < betAmounts[currentBetIndex]:
		print("Insufficent Funds!")
		emit_signal("server_error", Enumerations.SERVERERROR.INSUFFICIENT_FUNDS)
		return
	
	balance -= betAmounts[currentBetIndex]
	is_spin_inprogress = true
	var spinResult = Spin()
	yield(pingTimer,"timeout")
	
#	spinResult.printSymbols()
	emit_signal("spin_result_ready", spinResult)

func Spin():
	previous_result = result
	
	result = SpinResult.new(3, 5, 3)
	result.spinType = current_game_mode
	
	createDefaultResult()
	result.winFactor = result.getTotalWin() / result.betAmount
	
	self.balance += getTotalWinAmount(result.winlineWinAmounts)
	result.balance = self.balance
	is_spin_inprogress = false
	
	return result

func createDefaultResult(data: Dictionary = {}):
	result.betAmount = betAmounts[currentBetIndex]
	
	result.symbols = results_queue[current_result_index]
	current_result_index = current_result_index + 1
	if current_result_index >= results_queue.size():
		current_result_index = 0
	
	result.isBonusTriggered = false
	result.winlineSymbolCounts = []
	result.winlineSymbols = []
	result.winSymbolPositions = []
	result.paylineId = []
	result.wildMultipliers = []
	result.wildSymbolPositions = []
	result.winlineWinAmounts = calculateWinAmounts(result.symbols)
	result.totalWin = result.getTotalWin()

func calculateWinAmounts(symbols):
	var resultArray = []
	
	getWildMiltipliers(symbols)
	
	for i in range(lines.size()):
		var lineResult = ""
		var lineChar = ""
		var multiplier = 1
		
		for index in symbols.size():
			if symbols[index][lines[i][index]] == wildSymbolIndex:
				lineResult += "w"
				
				if result.wildMultipliers && result.wildMultipliers[index] && result.wildMultipliers[index][lines[i][index]]:
					multiplier = result.wildMultipliers[index][lines[i][index]]
				
			else:
				lineResult += str(symbols[index][lines[i][index]])
				# Handle Wild
				if lineChar == "":
					lineChar = str(symbols[index][lines[i][index]]) # Will be replaced with wild symbols later-on
		
		if lineChar != "": # Replace if there is a non-wild symbol in line
			lineResult = lineResult.replace("w", lineChar)
			
		if paytable.has(lineResult): # Full Line First
			resultArray.push_front(paytable[lineResult] * betAmounts[currentBetIndex] * multiplier)
			result.winlineMultiplier.push_front(paytable[lineResult])
			result.winlineSymbolCounts.push_front(5)
			result.winlineSymbols.push_front(symbols[0][lines[i][0]])
			result.winSymbolPositions.push_front([lines[i][0], lines[i][1], lines[i][2], lines[i][3], lines[i][4]])
			result.paylineId.push_front(i+1)
			result.winFactor += paytable[lineResult]
		elif paytable.has(lineResult.left(4)):
			resultArray.push_front(paytable[lineResult.left(4)] * betAmounts[currentBetIndex] * multiplier)
			result.winlineMultiplier.push_front(paytable[lineResult.left(4)])
			result.winlineSymbolCounts.push_front(4)
			result.winlineSymbols.push_front(symbols[0][lines[i][0]])
			result.winSymbolPositions.push_front([lines[i][0], lines[i][1], lines[i][2], lines[i][3]])
			result.paylineId.push_front(i+1)
			result.winFactor += paytable[lineResult.left(4)]
		elif paytable.has(lineResult.left(3)):
			resultArray.push_front(paytable[lineResult.left(3)] * betAmounts[currentBetIndex] * multiplier)
			result.winlineMultiplier.push_front(paytable[lineResult.left(3)])
			result.winlineSymbolCounts.push_front(3)
			result.winlineSymbols.push_front(symbols[0][lines[i][0]])
			result.winSymbolPositions.push_front([lines[i][0], lines[i][1], lines[i][2]])
			result.paylineId.push_front(i+1)
			result.winFactor += paytable[lineResult.left(3)]
		elif paytable.has(lineResult.left(2)):
			resultArray.push_front(paytable[lineResult.left(2)] * betAmounts[currentBetIndex] * multiplier)
			result.winlineMultiplier.push_front(paytable[lineResult.left(2)])
			result.winlineSymbolCounts.push_front(2)
			result.winlineSymbols.push_front(symbols[0][lines[i][0]])
			result.winSymbolPositions.push_front([lines[i][0], lines[i][1]])
			result.paylineId.push_front(i+1)
			result.winFactor += paytable[lineResult.left(2)]
	
	return resultArray

func getTotalWinAmount(winArray):
	var total = 0
	for i in winArray:
		total+=i
	return total


func getWildMiltipliers(symbols) -> void:
	var counter := 0
#	
	for index in symbols.size():
		result.wildMultipliers.append([])
		for i in symbols[index].size():
			if symbols[index][i] == wildSymbolIndex:
				counter += 1
				result.wildMultipliers[index].append(counter)
				result.wildSymbolPositions.append([index, i])
				result.isBonusTriggered = true
			else:
				result.wildMultipliers[index].append(null)

func getGameData():
	return DEFAULT_GAME_DATA

func getPlayerData():
	return DEFAULT_GAME_DATA["playerData"]
