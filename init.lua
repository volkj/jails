--[[
-- Jail mod by ShadowNinja
-- Datastorage support added by Volkj
--]]

local is_datastorage_available = minetest.get_modpath( "datastorage" ) and true

jails = {
	jails 			= {},
	filename 		= minetest.get_worldpath() .. DIR_DELIM .. "jails.lua",
	default 		= 0,
	announce 		= minetest.setting_getbool( "jails.announce" ),
	teleportDelay 	= tonumber(minetest.setting_get( "jails.teleport_delay" ) ) or 30,
	datastorage 	= is_datastorage_available,
}

if jails.datastorage then
	minetest.debug("Jails: datastorage support enabled")
	jails[ "sentences" ] = {}		-- { { timestamp = os.time(), jailer = jailer_name , reason = "", severity = "low/mid/high/manual" } }
	jails[ "sentence_lenght" ] = {
		jail = {	-- lenght of sentence in seconds
			low  = 1800,	-- 30 min
			mid  = 3600,	-- 1 h
			high = 10800,	-- 3 h
		},
		ban	 = {
			low  = 86400,	-- 1 day
			mid  = 604800,	-- 1 week
			high = 2592000,	-- 1 month (30 days)
		},
	}
end

local modPath = minetest.get_modpath(minetest.get_current_modname()) .. DIR_DELIM

dofile(modPath .. "api.lua")
dofile(modPath .. "commands.lua")

minetest.register_privilege("jailer", "Can jail players")

local function keepInJail(player)
	local jailName, jail = jails:getJail(player:get_player_name())
	if jail then
		player:setpos(jail.pos)
		return true  -- Don't spawn normaly
	end
end

minetest.register_on_joinplayer(keepInJail)
minetest.register_on_respawnplayer(keepInJail)

local stepTime = 0
minetest.register_globalstep(function(dtime)
	stepTime = stepTime + dtime
	if stepTime < jails.teleportDelay then
		return
	end
	stepTime = 0
	for _, player in pairs(minetest.get_connected_players()) do
		keepInJail(player)
	end
end)

jails:load()
