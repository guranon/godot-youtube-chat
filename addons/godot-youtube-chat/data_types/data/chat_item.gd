# ChatItem.gd
class_name ChatItem
extends RefCounted

var id: String
var author: Author
var message: Array[MessageItem] = []
var superchat: Superchat = null
## Is the user a member?
var is_membership: bool
var is_verified: bool
var is_owner: bool
var is_moderator: bool
var timestamp: int   # store as Unix epoch (int) instead of Date
## Indicates a membership subscription chat item
var is_membership_chat : bool
