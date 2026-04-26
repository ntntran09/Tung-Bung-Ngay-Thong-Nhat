extends Node

func info(message: String) -> void:
	if AppConfig.is_debug_logging_enabled():
		print(message)

func value(message: String, value: Variant) -> void:
	if AppConfig.is_debug_logging_enabled():
		print(message, value)
