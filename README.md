# Godot YouTube Chat
> Fetch YouTube live chat without API in Godot

☢ ***You will need to take full responsibility for your action*** ☢

## Usage
In a scene:
- Add a `YTLiveChat` node
- Add a `YTRequests` node
- On the `YTLiveChat` node:
	- Set `@export var` Requests to the `YTRequests` node
	- Set one of either Channel ID, Live ID, or Handle on the `YTLiveChat` node
		- Channel ID
			- Example: `https://www.youtube.com/channel/{UCiC...}`
		- Live ID
			- Example: `https://www.youtube.com/watch?v={bt42DMw70os}`
			- If using Live ID, you'll have to change this for each new stream.
		- Handle
			- Example: `https://www.youtube.com/@{niminightmare}`
			- `@` is optional, with or without is supported.
- In your own script, connect to `signal chat_received(chat_item: ChatItem)` on `YTLiveChat` to handle chat messages as desired.
	- See [`chat_item.gd`](addons/godot-youtube-chat/data_types/data/chat_item.gd)
- Call `start()` on the `YTLiveChat` node to connect to chat and start emitting `chat_received` signals.

See [`example.tscn`](example/example.tscn) for an example.

## Notes
Heavily based on https://github.com/LinaTsukusu/youtube-chat.

The majority of the code was translated from TypeScript, assisted by AI and human-reviewed.

### Changes
- `ChatItem` has a `var is_membership_chat : bool` to indicate a membership subscription chat (green).
  - Not to be confused with `var is_member : bool` indicating that the chat was from a member.
