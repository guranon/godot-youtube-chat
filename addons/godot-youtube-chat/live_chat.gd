extends Node
class_name YTLiveChat

# --- Signals ---
signal started(live_id: String)
signal ended(reason: String)
signal chat_received(chat_item: ChatItem)
signal error_occurred(message: String)

# --- Exported properties ---
@export_group("Dependencies")
@export var requests: YTRequests
@export_group("YouTube ID (set one of these)")
## Only one of these needs to be set. If multiple are set, priority is channel_id > live_id > handle.
@export var channel_id: String = ""
@export var live_id: String = ""
@export var handle: String = ""

@export_group("Other")
@export var interval_ms: int = 1000

# --- Internal state ---
var _options: FetchOptions = null
var _timer: Timer

func _ready() -> void:
	if requests == null:
		requests = YTRequests.new()
		add_child(requests)

	requests.live_page_fetched.connect(_on_live_page_fetched)
	requests.chat_fetched.connect(_on_chat_fetched)

	_timer = Timer.new()
	_timer.wait_time = float(interval_ms) / 1000.0
	_timer.one_shot = false
	_timer.autostart = false
	add_child(_timer)
	_timer.timeout.connect(_execute)


# --- Public API ---
func start() -> void:
	if not _timer.is_stopped():
		return
	var id_dict := _build_youtube_id()
	if id_dict.is_empty():
		push_error("Required channel_id or live_id or handle.")
		error_occurred.emit("Missing YoutubeId")
		return
	requests.fetch_live_page(id_dict)


func stop(reason: String = "") -> void:
	if not _timer.is_stopped():
		_timer.stop()
		ended.emit(reason)


# --- Signal Handlers ---
func _on_live_page_fetched(options: Dictionary) -> void:
	if options.is_empty():
		error_occurred.emit("Failed to fetch live page")
		stop("Failed to fetch live page")
		return

	_options = FetchOptions.new()
	_options.api_key = options["api_key"]
	_options.client_version = options["client_version"]
	_options.continuation = options["continuation"]

	live_id = options["live_id"]
	started.emit(live_id)

	_timer.start()


func _on_chat_fetched(chat_items: Array, continuation: String) -> void:
	if _options == null:
		error_occurred.emit("Not found options")
		stop("Not found options")
		return

	for chat_item in chat_items:
		chat_received.emit(chat_item)

	_options.continuation = continuation


# --- Execution Loop ---
func _execute() -> void:
	if _options == null:
		error_occurred.emit("Not found options")
		stop("Not found options")
		return
	requests.fetch_chat(_options)


# --- Helper ---
func _build_youtube_id() -> Dictionary:
	if channel_id != "":
		return {"channel_id": channel_id}
	elif live_id != "":
		return {"live_id": live_id}
	elif handle != "":
		return {"handle": handle}
	return {}
