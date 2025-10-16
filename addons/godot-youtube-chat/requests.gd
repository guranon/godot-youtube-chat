class_name YTRequests
extends Node

signal live_page_fetched(options: Dictionary)
signal chat_fetched(chat_items: Array, continuation: String)

const BASE_URL := "https://www.youtube.com"

var _http : HTTPRequest
var _pending : String = ""


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func fetch_live_page(id_dict: Dictionary) -> void:
	var url = _generate_live_url(id_dict)
	if url == "":
		push_error("not found id")
		live_page_fetched.emit({})
		return
	var err = _http.request(url)
	if err != OK:
		push_error("HTTP request failed to start (live page)")
		live_page_fetched.emit({})
		return
	_pending = "live_page"


func fetch_chat(options: FetchOptions) -> void:
	var url = "%s/youtubei/v1/live_chat/get_live_chat?key=%s" % [BASE_URL, options.api_key]
	var body = {
		"context": {
			"client": {
				"clientVersion": options.client_version,
				"clientName": "WEB"
			}
		},
		"continuation": options.continuation
	}
	var headers = ["Content-Type: application/json"]
	var err = _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("HTTP request failed to start (chat)")
		return
	_pending = "chat"


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("HTTP request failed with code %d" % response_code)
		return

	var text = body.get_string_from_utf8()

	match _pending:
		"live_page":
			var options = YTParser.get_options_from_live_page(text)
			live_page_fetched.emit(options)
		"chat":
			var data = JSON.parse_string(text)
			if typeof(data) != TYPE_DICTIONARY:
				push_error("Invalid JSON response")
				return
			var parsed = YTParser.parse_chat_data(data)
			var chat_items: Array = parsed[0]
			var continuation: String = parsed[1]
			chat_fetched.emit(chat_items, continuation)

	_pending = ""


func _generate_live_url(id_dict: Dictionary) -> String:
	if id_dict.has("channel_id") and id_dict["channel_id"] != "":
		return "%s/channel/%s/live" % [BASE_URL, id_dict["channel_id"]]
	elif id_dict.has("live_id") and id_dict["live_id"] != "":
		return "%s/watch?v=%s" % [BASE_URL, id_dict["live_id"]]
	elif id_dict.has("handle") and id_dict["handle"] != "":
		var handle = id_dict["handle"]
		if not handle.begins_with("@"):
			handle = "@" + handle
		return "%s/%s/live" % [BASE_URL, handle]
	return ""
