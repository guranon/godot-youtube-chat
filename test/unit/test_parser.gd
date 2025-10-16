extends "res://addons/gut/test.gd"

# Utility to load JSON testdata
func load_json(path: String) -> Dictionary:
	return JSON.parse_string(load_text(path))

# Utility to load text fixtures (HTML pages)
func load_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return text

# -------------------------------
# Tests
# -------------------------------

func test_parse_normal():
	var res = load_json("res://test/testdata/get_live_chat.normal.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]
	var continuation: String = result[1]

	assert_eq(continuation, "test-continuation:01")
	assert_eq(chat_items.size(), 1)

	var chat: ChatItem = chat_items[0]
	assert_eq(chat.id, "id")
	assert_eq(chat.author.name, "authorName")
	assert_eq(chat.author.thumbnail.url, "https://author.thumbnail.url")
	assert_eq(chat.message[0].text, "Hello, World!")
	assert_false(chat.is_membership)
	assert_false(chat.is_verified)
	assert_false(chat.is_owner)
	assert_false(chat.is_moderator)

func test_parse_global_emoji1():
	var res = load_json("res://test/testdata/get_live_chat.global-emoji1.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]
	var continuation: String = result[1]

	assert_eq(continuation, "test-continuation:01")
	var emoji: EmojiItem = chat_items[0].message[0].emoji
	assert_eq(emoji.url, "https://www.youtube.com/s/gaming/emoji/828cb648/emoji_u1f44f.svg")
	assert_eq(emoji.alt, ":clapping_hands:")
	assert_false(emoji.is_custom_emoji)
	assert_eq(emoji.emoji_text, "👏")

func test_parse_custom_emoji():
	var res = load_json("res://test/testdata/get_live_chat.custom-emoji.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	var emoji: EmojiItem = chat_items[0].message[0].emoji
	assert_eq(emoji.url, "https://custom.emoji.url")
	assert_eq(emoji.alt, ":customEmoji:")
	assert_true(emoji.is_custom_emoji)
	assert_eq(emoji.emoji_text, ":customEmoji:")

func test_parse_from_membership():
	var res = load_json("res://test/testdata/get_live_chat.from-member.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	var chat: ChatItem = chat_items[0]
	assert_true(chat.is_membership)
	assert_eq(chat.author.badge.label, "メンバー（6 か月）")
	assert_eq(chat.author.badge.thumbnail.url, "https://membership.badge.url")

func test_parse_subscribe_membership():
	var res = load_json("res://test/testdata/get_live_chat.subscribe-member.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	var chat: ChatItem = chat_items[0]
	assert_eq(chat.id, "id")
	assert_eq(chat.author.name, "authorName")
	assert_eq(chat.author.thumbnail.url, "https://author.thumbnail.url")
	assert_eq(chat.author.channel_id, "channelId")
	assert_eq(chat.author.badge.label, "新規メンバー")
	assert_eq(chat.author.badge.thumbnail.url, "https://membership.badge.url")
	assert_eq(chat.author.badge.thumbnail.alt, "新規メンバー")
	assert_eq(chat.message[0].text, "上級エンジニア")
	assert_eq(chat.message[1].text, " へようこそ！")
	assert_true(chat.is_membership)
	assert_false(chat.is_verified)
	assert_false(chat.is_owner)
	assert_false(chat.is_moderator)
	assert_true(chat.is_membership_chat)

func test_parse_superchat():
	var res = load_json("res://test/testdata/get_live_chat.super-chat.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	var chat: ChatItem = chat_items[0]
	assert_not_null(chat.superchat)
	assert_eq(chat.superchat.amount, "￥1,000")
	assert_eq(chat.superchat.color, Color("#FFCA28"))

func test_parse_supersticker():
	var res = load_json("res://test/testdata/get_live_chat.super-sticker.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	var chat: ChatItem = chat_items[0]
	assert_not_null(chat.superchat)
	assert_eq(chat.superchat.amount, "￥90")
	assert_eq(chat.superchat.color, Color("#1565C0"))
	assert_eq(chat.superchat.sticker.url, "//super.sticker.url")
	assert_eq(chat.superchat.sticker.alt, "superSticker")

func test_parse_verified():
	var res = load_json("res://test/testdata/get_live_chat.from-verified.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	assert_true(chat_items[0].is_verified)

func test_parse_moderator():
	var res = load_json("res://test/testdata/get_live_chat.from-moderator.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	assert_true(chat_items[0].is_moderator)

func test_parse_owner():
	var res = load_json("res://test/testdata/get_live_chat.from-owner.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	assert_true(chat_items[0].is_owner)

func test_parse_no_chat():
	var res = load_json("res://test/testdata/get_live_chat.no-chat.json")
	var result = YTParser.parse_chat_data(res)
	var chat_items: Array = result[0]

	assert_eq(chat_items.size(), 0)

func test_get_options_normal():
	var html = load_text("res://test/testdata/live-page.html")
	var options = YTParser.get_options_from_live_page(html)

	assert_true(options.size() > 0)
	assert_typeof(options["live_id"], TYPE_STRING)
	assert_typeof(options["api_key"], TYPE_STRING)
	assert_typeof(options["client_version"], TYPE_STRING)
	assert_typeof(options["continuation"], TYPE_STRING)

func test_get_options_replay_finished():
	var html = load_text("res://test/testdata/replay_page.html")
	var options = YTParser.get_options_from_live_page(html)
	assert_eq(options.size(), 0)  # error → empty dict
	assert_push_error("is finished live")

func test_get_options_no_live():
	var html = load_text("res://test/testdata/no_live_page.html")
	var options = YTParser.get_options_from_live_page(html)
	assert_eq(options.size(), 0)  # error → empty dict
	assert_push_error("Live Stream was not found")
