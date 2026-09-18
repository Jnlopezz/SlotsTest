class_name SpinResult
extends Resource

var betAmount
var spinType
var reelPositions
var symbols
var winlineWinAmounts
var winlineSymbols
var winlineSymbolCounts
var anticipationReelIndexes
var balance
var winSymbolPositions
var rowSize
var colSize
var totalWin
var winFactor
var totalWinFactor
var roundId
var wildMultipliers
var winlineMultiplier
var paylineId

var isBonusTriggered: bool
var isBonusFinished: bool
var isMaxWinTriggered: bool

func printSymbols():
	print_debug(_to_string())

func _to_string() -> String:
	var line = ""
	# TODO Fix Ranges to become dynamic
	for i in range(rowSize):
		for j in range(colSize):
			line += str(symbols[j][i])
		line += "\n"
	
#	line += "winlineWinAmounts : " + str(winlineWinAmounts) + "\n"
#	line += "winSymbolPositions : " + str(winSymbolPositions) + "\n"
#	line += "winlineSymbols : " + str(winlineSymbols) + "\n"
#	line += "winlineSymbolCounts : " + str(winlineSymbolCounts) + "\n"
	return line

func _init(rowCount, columnCount, winLineCount):
	rowSize = rowCount
	colSize = columnCount
	
	# Init reelPositions Array
	reelPositions = []
	reelPositions.resize(colSize)
	
	# Init reelPositions Array
	winlineWinAmounts = []
	winlineSymbols = []
	winlineSymbolCounts = []
	winSymbolPositions = []
	winlineMultiplier = []
	paylineId = []
	winFactor = 0
	
	# Init symbols 2D Array
	symbols = []
	for x in range(colSize):
		symbols.append([])
		for y in range(rowSize):
			symbols[x].append(0)

func getTotalWin() -> float:
	var win = 0
	for i in winlineWinAmounts.size():
		win += winlineWinAmounts[i]
	return win

# Returns the Merged version of all winline symbols in an Array
func getCombinedWinPositions() -> Array:
	var allWins = []
	allWins.resize(colSize)
	for colIndex in colSize:
		allWins[colIndex] = []
		for lineIndex in winSymbolPositions.size():
			if colIndex < winSymbolPositions[lineIndex].size() and !allWins[colIndex].has(winSymbolPositions[lineIndex][colIndex]):
				allWins[colIndex].push_back(winSymbolPositions[lineIndex][colIndex])
				
	for index in allWins.size():
		if allWins[index].size() == 0:
			allWins.resize(index)
			break
		
	return allWins

# Returns Values that stored in this result data
# Add string values to filter array to print only those values
# Prints all values if the filter is empty
# e.g. print(result.printValues())
# e.g. print(result.printValues(["total_bonus_round", "isBonusFinished", "totalWin"]))
func printValues(filter:Array = []) -> String:
	var thisScript: GDScript = get_script()
	var result := ""
	
	if filter.size() == 0:
		for propertyInfo in thisScript.get_script_property_list():
			result += "\t" + propertyInfo.name + ": " + str(get(propertyInfo.name))
	else:
		for propertyInfo in thisScript.get_script_property_list():
			if filter.has(propertyInfo.name):
				result += "\t" + propertyInfo.name + ": " + str(get(propertyInfo.name))
	return result
