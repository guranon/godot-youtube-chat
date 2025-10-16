extends Node

@export var live_chat : YTLiveChat

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	live_chat.chat_received.connect(func(chat : ChatItem):
		for message in chat.message:
			if message.text:
				print(message.text)
			elif message.emoji:
				print(message.emoji.emoji_text)
	)
	live_chat.start()
