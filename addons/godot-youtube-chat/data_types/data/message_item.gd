## Represents either plain text or an EmojiItem
class_name MessageItem
extends RefCounted

var text: String = ""          # if it's plain text
var emoji: EmojiItem = null    # if it's an emoji
