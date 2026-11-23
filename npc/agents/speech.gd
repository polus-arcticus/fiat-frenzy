## What someone last said, and their cooldowns: Chatter's, by the speaker's uid (Chatter.of). Passing state: nothing a save
## keeps, so nobody carries it on them.
class_name Speech
extends RefCounted

var line := ""            # what they last said
var ttl := 0.0            # how much longer it stays up
var seq := 0              # counts up with each new line, so a view can tell
var near_cooldown := 0.0  # before another "close" line
var event_cooldown := 0.0 # before another money line
