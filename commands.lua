
local posMatch =
		"(-?%d+)[%s%,]+"..
		"(-?%d+)[%s%,]+"..
		"(-?%d+)"
local jailNameMatch = "[%*A-Za-z0-9_%-%.][A-Za-z0-9_%-%.]*"

local function normalizeJailName(jailName)
	return jailName ~= "*" and jailName or jails.default
end

-- keep jail cmd, only admin can use it with datastorage - it will set a manual flag
minetest.register_chatcommand("jail", {
	params = "[Player] [Jail]",
	description = "Jail a player.",
	privs = {jailer=true},
	func = function(name, param)
		if param == "" then
				--
				-- Default mod's behavior puts the invoking player in jail
				-- Changed to show a message, swap the comment statements to enable default behavior
				--
				-- return jails:jail(name)
			return false, "This would have jailed you. Be careful next time."
		end
		local playerName, jailName = param:match("^(%S+)%s("..jailNameMatch..")$")
		if playerName then
			return jails:jail(playerName, normalizeJailName(jailName))
		elseif jails:playerExists(param) then
			return jails:jail(param)
		end
		local jailName = normalizeJailName(param)
		if jails.jails[jailName] then
			return jails:jail(name, jailName)
		end
		return false, "That jail/player does not exist."
	end
})

minetest.register_chatcommand("unjail", {
	params = "[Player]",
	description = "Unjail a player or yourself",
	privs = {jailer=true},
	func = function(name, param)
		--if datastorage and not priv server then return false, "Error: only an admin can unjail players"
		if param == "" then
			if jails:getJail(name) then
				jails:unjail(name)
				return true, "You are no longer jailed."
			else
				return false, "You are not jailed."
			end
		end
		local ok, message = jails:unjail(param)
		if not ok then return ok, message end
		message = ("Player %q let free."):format(param)
		if not minetest.get_player_by_name(param) then
			message = message .. "  The unjailed player is not "..
				"online now, they will be removed from the "..
				"jail roster but not moved out of the jail."
		end
		return true, message
	end,
})


minetest.register_chatcommand("add_jail", {
	params = "[jail] [X Y Z|X,Y,Z]",
	description = "Adds a new jail at your coordinates or the ones specified.",
	privs = {jailer=true},
	func = function(name, param)
		local errMustBeConnected = "You must be connected to use this command without a position."
		if param == "" then
			local player = minetest.get_player_by_name(name)
			if not player then return false, errMustBeConnected end
			if jails.jails[jails.default] then
				return false, "The default jail already exists."
			end
			local pos = vector.round(player:getpos())
			jails:add(jails.default, pos)
			return true, ("Default jail added at %s.")
				:format(minetest.pos_to_string(pos))
		end
		local jailName, x, y, z = param:match(
				"^("..jailNameMatch..")%s"..posMatch.."$")
		if not jailName then
			x, y, z = param:match("^"..posMatch.."$")
		else
			jailName = normalizeJailName(jailName)
		end
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		local pos = vector.new(x, y, z)

		-- If they typed the name and coordinates
		if jailName then
			if jails.jails[jailName] then
				return false, "Jail already exists."
			end
			jails:add(jailName, pos)
			return true, ("Jail added at %s.")
					:format(minetest.pos_to_string(pos))
		-- If they just typed the jail name
		elseif param:find("^"..jailNameMatch.."$") then
			jailName = normalizeJailName(param)
			if jails.jails[jailName] then
				return false, "Jail already exists!"
			end
			local player = minetest.get_player_by_name(name)
			if not player then return false, errMustBeConnected end
			pos = vector.round(player:getpos())
			jails:add(jailName, pos)
			return true, ("Jail added at %s.")
					:format(minetest.pos_to_string(pos))
		-- If they just typed the coordinates
		elseif x then
			if jails.jails[jails.default] then
				return false, "The default jail already exists!"
			end
			local ok, err = jails:add(jails.default, pos)
			if not ok then return false, err end
			return true, ("Default jail added at %s.")
					:format(minetest.pos_to_string(pos))
		end
		return false, ("Invalid jail name (%s allowed).")
				:format(jailNameMatch)
	end
})


minetest.register_chatcommand("remove_jail", {
	params = "[Jail [NewJail]]",
	description = "Remove a jail, unjailing all players in it or moving them to a new jail.",
	privs = {jailer=true},
	func = function(name, param)
		if param == "" then
			local ok, err = jails:remove()
			if not ok then return false, err end
			return true, "Default jail removed."
		end
		local oldJailName, newJailName = param:match("^("..jailNameMatch
				..")%s("..jailNameMatch..")$")
		if oldJailName then
			oldJailName, newJailName = normalizeJailName(oldJailName), normalizeJailName(newJailName)
			local ok, err = jails:remove(oldJailName, newJailName)
			if not ok then return false, err end
			return true, "Jail replaced."
		end
		oldJailName = normalizeJailName(param)
		if jails.jails[oldJailName] then
			local ok, err = jails:remove(oldJailName)
			if not ok then return false, err end
			return true, "Jail removed."
		end
		return false, ("Invalid jail name(s). (%s allowed).")
				:format(jailNameMatch)
	end
})


minetest.register_chatcommand("list_jails", {
	params = "[Jail]",
	description = "Prints information on all jails or a specific jail.",
	func = function(name, param)
		local function formatJail(name, data)
			local captiveNames = {}
			for captiveName in pairs(data.captives) do
				table.insert(captiveNames, captiveName)
			end
			return ("%s %s: %s"):format(
					name ~= jails.default and name or "<Default>",
					minetest.pos_to_string(data.pos),
					table.concat(captiveNames, ", ")
				)
		end
		if param == "" then
			local t = {"List of all jails:"}
			for jailName, data in pairs(jails.jails) do
				table.insert(t, formatJail(jailName, data))
			end
			return true, table.concat(t, "\n")
		end
		local jailName = normalizeJailName(param)
		if jails.jails[jailName] then
			return true, formatJail(jailName, jails.jails[jailName])
		end
		return false, "Jail does not exist."
	end
})


minetest.register_chatcommand("move_jail", {
	params = "[Jail] [X Y Z|X,Y,Z]",
	description = "Moves a jail.",
	privs = {jailer=true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		local function doMove(jailName, pos)
			local jail = jails.jails[jailName]
			jail.pos = pos
			for name, data in pairs(jail.captives) do
				local player = minetest.get_player_by_name(data)
				if player then
					player:setpos(jails:getSpawnPos(data.pos))
				end
			end
			jails:save()
		end
		if param == "" then
			if not jails.jails[jails.default] then
				return false, "The default jail does not exist yet!"
			end
			local pos = vector.round(player:getpos())
			doMove(jails.default, pos)
			return true, ("Default jail moved to %s.")
					:format(minetest.pos_to_string(pos))
		end

		local jailName, x, y, z = param:match("^("..jailNameMatch
				..")%s"..posMatch.."$")
		if not jailName then
			x, y, z = param:match("^"..posMatch.."$")
		end
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		local pos = vector.new(x, y, z)

		-- If they typed the name and coordinates
		if jailName then
			jailName = normalizeJailName(jailName)
			if not jails.jails[jailName] then
				return false, "Jail does not exist."
			end
			doMove(jailName, pos)
			return true, ("Jail moved to %s.")
					:format(minetest.pos_to_string(pos))
		-- If they just typed the jail name
		end
		jailName = normalizeJailName(param)
		if jails.jails[jailName] then
			local pos = vector.round(player:getpos())
			doMove(jailName, pos)
			return true, ("Jail moved to %s")
				:format(minetest.pos_to_string(pos))
		-- If they just typed the coordinates
		elseif x then
			if not jails.jails[jails.default] then
				return false, "The default jail does not exist yet!"
			end
			doMove(jails.default, pos)
			return true, ("Default jail moved to %s.")
					:format(minetest.pos_to_string(pos))
		end
		return false, ("Invalid jail name (%s allowed).")
				:format(jailNameMatch)
	end
})

if jails.datastorage then
	--TODO add an unjail cmd only admin/server priv can use
	--TODO implement with formspecs, can save some params = more fast to use
	minetest.register_chatcommand( "sentence", {
		params = "<player> <severity = low/mid/high> <reason>",
		description = "Jail a player once provided a severity level and reason of jailing",
		privs = { jailer = true } ,
		func = function( name, param )
			--check params
			local error_usage = "Usage: /sentence <player> <severity = low/mid/high> <reason>"
			if param == "" then
				return false, error_usage
			end
			local parameters = {}
			local parameters.player, parameters.severity, parameters.reason = string.match( string, "([a-z,A-Z,0-9]+) (%a+) (.+)" )
			if ( not parameters.player ) or ( not parameters.severity ) or ( not parameter.reason ) then
				return false, error_usage
			elseif 	( not parameters.severity == "low" ) or
					( not parameters.severity == "mid" ) or
					( not parameters.severity == "high" ) then
						return false, "Error: severity must be low/mid/high"
			end
			--minetest.get_player_by_name( parameters.player )
			-- add sentence to jails.sentences table
			jails.sentences[ name ] = {
				jailed = parameters.player,
				timestamp = os.time(),
				reason = parameters.reason,
				severity = parameters.severity,
			}
			-- ask to approve sentence
			-- if affirmative, jail player and save the sentence in player's datastorage
				-- clear jails.sentences table for the player
			minetest.chat_send_player( name, "Jailing " .. parameters.player .. " with " .. parameters.severity
										.. " sentence for reason: " .. parameters.reason )
			minetest.chat_send_player( name, "Confirm sentence with /sy" )
			return true

		end
	--have to print a question, "Sentencing player to months weeks days hours minutes of jail, answer /sy to confirm"
	--before giving another sentence, print back the one already not confirmed
	-- table jails.accept_queue[ jailer ] = timestamp
	-- if timestamp < 30 return same question

	-- /sy cmd
	--
	-- if timestamp and timestamp > 30 return "no sentences in queue"
	--

	})

	minetest.register_chatcommand( "sy", {
		params = "",
		description = "Apply a pending sentence and jail the player",
		privs = { jailer = true },


		func = function( name )
			if not jails.sentences[ name ] then
				return false, "Error: no sentence pending approval available"
			end
			-- jail player
			local player_record = datastorage.get( jails.sentences[ name ].jailed, "jails" )
			local time_jailed = ( player_record[ "time_jailed" ] or 0 ) + 1
			local total_jailed_time = player_record[ "total_jailed_time" ] or 0
			if ( time_jailed > 10) or ( total_jailed_time > jails.sentence_length.ban.high * 2 ) then	-- swapped conditions, it was a race condition ( 5 evalued before 10)
				player_record[ "definitive_ban" ] = true
			elseif ( time_jailed > 5 ) or ( total_jailed_time > jails.sentence_length.jail.high * 2 ) then
				player_record[ "is_bannable" ] = true
			end

			-- Get the time the player will be jailed
			local sentence_length
			if player_record[ "is_bannable" ] then	--TODO set is_bannable true on ban sentences (default: 2*high or more than 5 jails)
				sentence_length = time_jailed * jails.sentence_length.ban[ jails.sentences[ name ].severity ]  --TODO add xban2 support
			else
				sentence_length = time_jailed * jails.sentence_length.jail[ jails.sentences[ name ].severity ]
			end

			local reason = jails.sentences[ name ].reason or "No reason given"

			if jails.sentences[ name ].severity == "manual" then
				reason = "Manually jailed by admin " .. name
						.. " " .. reason
			end

			table.insert( player_record[ "sentence_list" ], time_jailed, {
												jailer = name,
												reason = reason,
												severity = jails.sentences[ name ].severity,
												timestamp = jails.sentences[ name ].timestamp,
												sentence_length = sentence_length,
			}

			player_record[ "sentence_length" ] = sentence_length
			player_record[ "sentence_start_time" ] = jails.sentences[ name ].timestamp
			player_record[ "total_jailed_time" ] = total_jailed_time + sentence_length
			player_record[ "time_jailed" ] = time_jailed + 1
	end,
	})
end
