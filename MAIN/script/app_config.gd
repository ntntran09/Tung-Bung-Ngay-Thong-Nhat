extends Node

const BACKEND_BASE_URL_SETTING := "application/config/backend_base_url"
const API_TIMEOUT_SETTING := "application/config/api_timeout_seconds"
const DEBUG_LOGGING_SETTING := "application/config/debug_logging"

const DEFAULT_API_TIMEOUT_SECONDS := 8.0

func backend_base_url() -> String:
	return str(ProjectSettings.get_setting(BACKEND_BASE_URL_SETTING, "")).strip_edges()

func api_timeout_seconds() -> float:
	var value = ProjectSettings.get_setting(API_TIMEOUT_SETTING, DEFAULT_API_TIMEOUT_SECONDS)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return maxf(float(value), 0.1)
	return DEFAULT_API_TIMEOUT_SECONDS

func is_debug_logging_enabled() -> bool:
	return bool(ProjectSettings.get_setting(DEBUG_LOGGING_SETTING, false))

func has_backend_base_url() -> bool:
	return not backend_base_url().is_empty()
