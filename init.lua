--[[
-- Jail mod by ShadowNinja
-- Datastorage support added by Volkj
--]]

local is_datastorage_available = minetest.get_modpath( "datastorage" ) and true --TODO use settings file

jails = {
	jails 			= {},
	filename 		= minetest.get_worldpath() .. DIR_DELIM .. "jails.lua",
	default 		= 0,
	announce 		= minetest.setting_getbool( "jails.announce" ),
	teleportDelay 	= tonumber(minetest.setting_get( "jails.teleport_delay" ) ) or 30,
	datastorage 	= is_datastorage_available,
}

if jails.datastorage then
	minetest.log( "info", "Jails: datastorage support enabled" )
	jails[ "last_sentence_is_ban" ] = true	-- what should jails do on the final sentence ( >10 times jailed or total jail time > ban.high * 2)
											-- on true, use minetest.ban( player )
											-- on false, keep player in jail ( needs a var to check if player is banned )
	jails[ "public_show_records" ] = true  -- should players jail record be visible by non-jailer players?
	jails[ "sentences" ] = {}		-- { jailer = { timestamp = os.time() , reason = "", severity = "low/mid/high/manual" } }
	jails[ "sentence_length" ] = {
		jail = {	-- length of sentence in seconds
			low  = 1800,	-- 30 min
			mid  = 3600,	-- 1 h
			high = 10800,	-- 3 h
		},
		ban	 = {	-- starts when jail times > 5 or total jail time > jail.high * 2
			low  = 86400,	-- 1 day
			mid  = 604800,	-- 1 week
			high = 2592000,	-- 1 month (30 days)
		},
	}
end

local modPath = minetest.get_modpath( minetest.get_current_modname() ) .. DIR_DELIM

dofile( modPath .. "api.lua" )
dofile( modPath .. "commands.lua" )

minetest.register_privilege( "jailer", "Can jail players" )

local function keepInJail( player )
	local jailName, jail = jails:getJail( player:get_player_name() )
	if jail then
		player:setpos( jail.pos )
		return true  -- Don't spawn normaly
	end
end

minetest.register_on_joinplayer( function( player )
	--if not player.sentence_started then sentence_started = os.time()
	keepInJail( player )
end)

minetest.register_on_respawnplayer( keepInJail )

local stepTime = 0
minetest.register_globalstep(function(dtime)
	stepTime = stepTime + dtime
	if stepTime < jails.teleportDelay then
		return
	end
	stepTime = 0
	for _, player in pairs(minetest.get_connected_players()) do
		--if timediff( now, start_sentence ) > player.sentence_severity then unjail
		keepInJail(player)
	end
end)

jails:load()
