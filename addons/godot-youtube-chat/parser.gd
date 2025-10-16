extends Node
class_name YTParser

# --- Utility functions ---

static func _convert_color(color_num: int) -> Color:
	# YouTube gives ARGB (alpha in the high 8 bits)
	var a = float((color_num >> 24) & 0xFF) / 255.0
	var r = float((color_num >> 16) & 0xFF) / 255.0
	var g = float((color_num >> 8) & 0xFF) / 255.0
	var b = float(color_num & 0xFF) / 255.0
	return Color(r, g, b, a)

static func _parse_thumbnail_to_image_item(data: Array, alt: String) -> ImageItem:
	var item := ImageItem.new()
	if data.size() > 0:
		var thumb = data.back()
		item.url = thumb.get("url", "")
		item.alt = alt
	else:
		item.url = ""
		item.alt = ""
	return item

# --- Message parsing ---

static func _parse_messages(runs: Array) -> Array[MessageItem]:
	var result: Array[MessageItem] = []
	for run in runs:
		var msg := MessageItem.new()
		if run.has("text"):
			msg.text = run["text"]
		elif run.has("emoji"):
			var emoji_data = run["emoji"]
			var thumb = emoji_data["image"]["thumbnails"][0] if emoji_data["image"]["thumbnails"].size() > 0 else {}
			var emoji := EmojiItem.new()
			emoji.url = thumb.get("url", "")
			emoji.alt = (emoji_data.get("shortcuts", []) as Array).front() if emoji_data.has("shortcuts") else ""
			emoji.is_custom_emoji = bool(emoji_data.get("isCustomEmoji", false))
			emoji.emoji_text = emoji.alt if emoji.is_custom_emoji else emoji_data.get("emojiId", "")
			msg.emoji = emoji
		result.append(msg)
	return result

# --- Renderer selection ---

static func _renderer_from_action(action: Dictionary) -> Dictionary:
	if not action.has("addChatItemAction"):
		return {}
	var item = action["addChatItemAction"]["item"]
	if item.has("liveChatTextMessageRenderer"):
		return item["liveChatTextMessageRenderer"]
	elif item.has("liveChatPaidMessageRenderer"):
		return item["liveChatPaidMessageRenderer"]
	elif item.has("liveChatPaidStickerRenderer"):
		return item["liveChatPaidStickerRenderer"]
	elif item.has("liveChatMembershipItemRenderer"):
		return item["liveChatMembershipItemRenderer"]
	return {}

# --- Action → ChatItem ---

static func _parse_action_to_chat_item(action: Dictionary) -> ChatItem:
	var renderer = _renderer_from_action(action)
	if renderer.is_empty():
		return null

	var chat := ChatItem.new()
	chat.id = renderer.get("id", "")

	# Author
	var author := Author.new()
	author.name = renderer.get("authorName", {}).get("simpleText", "")
	author.thumbnail = _parse_thumbnail_to_image_item(renderer.get("authorPhoto", {}).get("thumbnails", []), author.name)
	author.channel_id = renderer.get("authorExternalChannelId", "")
	chat.author = author

	# Message
	var runs: Array = []
	if renderer.has("message"):
		runs = renderer["message"].get("runs", [])
	elif renderer.has("headerSubtext"):
		runs = renderer["headerSubtext"].get("runs", [])
	chat.message = _parse_messages(runs)

	# Flags
	chat.is_membership = false
	chat.is_owner = false
	chat.is_verified = false
	chat.is_moderator = false
	chat.timestamp = int(renderer.get("timestampUsec", "0").to_int() / 1000)
	chat.is_membership_chat = action["addChatItemAction"]["item"].has("liveChatMembershipItemRenderer")

	# Badges
	if renderer.has("authorBadges"):
		for entry in renderer["authorBadges"]:
			var badge_data = entry.get("liveChatAuthorBadgeRenderer", {})
			if badge_data.has("customThumbnail"):
				var badge := Badge.new()
				badge.thumbnail = _parse_thumbnail_to_image_item(badge_data["customThumbnail"]["thumbnails"], badge_data["tooltip"])
				badge.label = badge_data["tooltip"]
				author.badge = badge
				chat.is_membership = true
			else:
				match badge_data.get("icon", {}).get("iconType", ""):
					"OWNER":
						chat.is_owner = true
					"VERIFIED":
						chat.is_verified = true
					"MODERATOR":
						chat.is_moderator = true

	# Superchat
	if renderer.has("sticker"):
		var sc := Superchat.new()
		sc.amount = renderer["purchaseAmountText"]["simpleText"]
		sc.color = _convert_color(renderer["backgroundColor"])
		sc.sticker = _parse_thumbnail_to_image_item(renderer["sticker"]["thumbnails"], renderer["sticker"]["accessibility"]["accessibilityData"]["label"])
		chat.superchat = sc
	elif renderer.has("purchaseAmountText"):
		var sc2 := Superchat.new()
		sc2.amount = renderer["purchaseAmountText"]["simpleText"]
		sc2.color = _convert_color(renderer["bodyBackgroundColor"])
		chat.superchat = sc2

	return chat

# --- Public API ---

static func parse_chat_data(data: Dictionary) -> Array:
	var chat_items: Array[ChatItem] = []
	var actions: Array = data.get("continuationContents", {}).get("liveChatContinuation", {}).get("actions", [])
	for act in actions:
		var chat_item = _parse_action_to_chat_item(act)
		if chat_item != null:
			chat_items.append(chat_item)

	# Continuation token
	var cont_data = data["continuationContents"]["liveChatContinuation"]["continuations"][0]
	var continuation: String = ""
	if cont_data.has("invalidationContinuationData"):
		continuation = cont_data["invalidationContinuationData"]["continuation"]
	elif cont_data.has("timedContinuationData"):
		continuation = cont_data["timedContinuationData"]["continuation"]

	return [chat_items, continuation]


static func get_options_from_live_page(data: String) -> Dictionary:
	var options := {}

	# --- Live ID ---
	var id_regex = RegEx.new()
	id_regex.compile("<link rel=\"canonical\" href=\"https:\\/\\/www.youtube.com\\/watch\\?v=(.+?)\">")
	var id_match = id_regex.search(data)
	if id_match:
		options["live_id"] = id_match.get_string(1)
	else:
		push_error("Live Stream was not found")
		return {}

	# --- Replay check ---
	var replay_regex = RegEx.new()
	replay_regex.compile("['\"]isReplay['\"]:\\s*(true)")
	if replay_regex.search(data):
		push_error("%s is finished live" % options["live_id"])
		return {}

	# --- API Key ---
	var key_regex = RegEx.new()
	key_regex.compile("['\"]INNERTUBE_API_KEY['\"]:\\s*['\"](.+?)['\"]")
	var key_match = key_regex.search(data)
	if key_match:
		options["api_key"] = key_match.get_string(1)
	else:
		push_error("API Key was not found")
		return {}

	# --- Client Version ---
	var ver_regex = RegEx.new()
	ver_regex.compile("['\"]clientVersion['\"]:\\s*['\"]([\\d.]+?)['\"]")
	var ver_match = ver_regex.search(data)
	if ver_match:
		options["client_version"] = ver_match.get_string(1)
	else:
		push_error("Client Version was not found")
		return {}

	# --- Continuation ---
	var cont_regex = RegEx.new()
	cont_regex.compile("['\"]continuation['\"]:\\s*['\"](.+?)['\"]")
	var cont_match = cont_regex.search(data)
	if cont_match:
		options["continuation"] = cont_match.get_string(1)
	else:
		push_error("Continuation was not found")
		return {}

	return options
