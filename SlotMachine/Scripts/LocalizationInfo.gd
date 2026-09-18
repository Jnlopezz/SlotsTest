class_name LocalizationInfo
extends Resource

## Money Text Delimiter for Decimal Value
export (String) var decimalSeperator: String = ","
## Money Text Delimiter for Thousands Values
export (String) var integerSeperator: String = "."
## Whether the Currency Symbol Shown on Front or Back of the Amount
export (bool) var isCurrencySymbolFirst: bool = false

func formatCurrencyText(value: float, currency: String) -> String:
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
