extends RefCounted

const EMPTY_RESULT := {
	"ok": false,
	"code": 0,
	"data": {},
	"error": "",
}

var request_node: HTTPRequest
var last_callback: Callable
var is_requesting := false

func _init(http_request: HTTPRequest):
	request_node = http_request
	request_node.timeout = AppConfig.api_timeout_seconds()

func request(path: String, body: Dictionary, callback: Callable) -> void:
	if is_requesting:
		_complete(0, {}, "Request already in progress", callback)
		return

	var base_url := AppConfig.backend_base_url()
	if base_url.is_empty():
		_complete(0, {}, "Backend base URL is not configured", callback)
		return

	last_callback = callback
	var headers := ["Content-Type: application/json"]
	var method := HTTPClient.METHOD_GET
	var payload := ""

	if not body.is_empty():
		method = HTTPClient.METHOD_POST
		payload = JSON.stringify(body)

	if not request_node.request_completed.is_connected(_on_request_completed):
		request_node.request_completed.connect(_on_request_completed, CONNECT_ONE_SHOT)

	is_requesting = true
	var err := request_node.request(base_url + path, headers, method, payload)
	if err != OK:
		is_requesting = false
		_complete(0, {}, "Request failed to start", callback)

func _on_request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	is_requesting = false
	if code != 200:
		_complete(code, {}, "Backend returned HTTP %d" % code, last_callback)
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_complete(code, {}, "Backend response is not valid JSON", last_callback)
		return

	last_callback.call({
		"ok": true,
		"code": code,
		"data": parsed,
		"error": "",
	})

func _complete(code: int, data: Dictionary, error: String, callback: Callable) -> void:
	var result := EMPTY_RESULT.duplicate()
	result["code"] = code
	result["data"] = data
	result["error"] = error
	callback.call(result)
