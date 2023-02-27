# Output-Util
A library for printing actions to the output for Luau.

Rather than using a function like `print(...)`, we can create an action that consists of a `method` that takes some values and returns a value to be printed.

For example;

```lua
local OutputUtil = require("PATH_TO_MODULE")

PLAYER_JOINED = {
	type = "ACTION";
	icon = "🧑‍🦲";
	method = function(player: Player)
		return ("%q (%s)"):format(player.DisplayName, player.Name)
	end;
}

-- the action name is case-insensitive, so 'PLAYER_joined'
-- will become 'PLAYER_JOINED' when loaded
OutputUtil.loadAction("PLAYER_joined", PLAYER_JOINED)

-- again, the action name is case-insensitive
OutputUtil("Player_Joined", playerThatJoined)
```