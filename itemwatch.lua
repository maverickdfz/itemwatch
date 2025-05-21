--[[
Copyright © 2025, Maverick
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of itemwatch nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Maverick BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'itemwatch'
_addon.version = '1.0'
_addon.author = 'Maverickdfz (Odin)'
_addon.commands = {'itemwatch', 'iw'}

require('string')
require('tables')
require('sqlite3')
require('logger')
texts = require('texts')
res = require('resources')
language = 'english'

config = require('config')
require('tables')

defaults = {}
defaults.ignore_recycle = true
defaults.items = L{}
defaults.item_limits = L{}
defaults.text_box_config = {pos={x=20,y=205},padding=8,text={font='sans-serif',size=10,stroke={width=2,alpha=255},Fonts={'sans-serif'},},bg={alpha=0},flags={}}

settings = config.load(defaults)

local watched_items = T{}

text_box = texts.new('', settings.text_box_config, settings)

counts = {}

show_debug = false

function update_text_variables()
	local items = windower.ffxi.get_items()
	local player_items = T{}
	for i,bag in pairs(res.bags) do
		local bag_name = bag.en
		bag_name = bag_name:gsub(' ','')
		bag_name = bag_name:lower()
		player_items[bag_name] = remap_item_list(items[bag_name])
	end
	for value in watched_items:it() do
		local item_name = value['name']:lower()
		local item_count = value['quantity']
		local current_count = 0
		for i,bag in pairs(res.bags) do
			local skip = false
			if bag.en == "Recycle" and settings.ignore_recycle then
				skip = true
			end
			if skip == false then
				local bag_name = bag.en
				bag_name = bag_name:gsub(' ','')
				bag_name = bag_name:lower()
				if not player_items[bag_name][item_name] then
					current_count = current_count + 0
				elseif player_items[bag_name][item_name].count then
					current_count = current_count + player_items[bag_name][item_name].count
				end
			end
		end
		a = ''

		if show_debug then
			print("item_name: " .. item_name)
			print("item_count: " .. item_count)
			print("current_count: " .. current_count)
		end
		count_max = tonumber(item_count)
		count_color_r = 0
		if current_count > count_max then
			count_color_r = 0
			count_color_g = 255
		else
			percent = (current_count/count_max * 100)
			if percent >=50 then
				count_color_g = 255
				count_color_r =math.floor(5 * (100-percent))
			else 
				count_color_r = 255
				count_color_g = 255-math.floor(5 * (50-percent))
			end
		end
		if current_count == 0 then
			a = "\\cs(255,0,0)" .. '0'
		else 
			a = "\\cs("..count_color_r..","..count_color_g..",0)" .. (current_count) 
		end

		if not counts[item_name] then
			counts[item_name] = T{text=""}
		end
		counts[item_name].text = a
	end
	if show_debug then
		table.vprint(counts)
	end
end

function text_box_string()
	local str = '           \\cs(130,130,130)Items\\cr\n'
	for value in watched_items:it() do
		local item_name = value['name']
		--print(item_name)
		local item_count = value['quantity']
		str = str.."\\cs(255,255,255)  "..item_name..": "..counts[item_name:lower()].text.."\\cr\n"
	end
	return str
end

function remap_item_list(itemlist)
    retarr = T{}
    for i,v in pairs(itemlist) do
        if type(v) == 'table' and v.id and v.id ~= 0 then
			if res.items[v.id] then
				local item_name = res.items[v.id][language]:lower()
				local item_name_log = res.items[v.id][language..'_log']:lower()
				-- If we don't already have the primary item name in the table, add it.
				if item_name and not retarr[item_name] then
					retarr[item_name] = table.copy(v)
					retarr[item_name].shortname=item_name
					-- If a long version of the name exists, and is different from the short version,
					-- add the long name to the info table and point the long name's key at that table.
					if item_name_log and item_name_log ~= item_name then
						retarr[item_name].longname = item_name_log
						retarr[item_name_log] = retarr[item_name]
					end
				elseif item_name then
					-- If there's already an entry for this item, all the hard work has already
					-- been done.  Just update the count on the subtable of the main item, and
					-- everything else will link together.
					retarr[item_name].count = retarr[item_name].count + v.count
				end
			end
        end
    end
    return retarr
end

windower.register_event('prerender', function()
	if not windower.ffxi.get_info().logged_in then
		text_box:hide()
        return
    end

	update_text_variables()
	text_box:text(text_box_string())
	text_box:show()
end)

function ttable_append_for_config(t, val)
    t[tostring(t:length()+1)] = val
    return t;
end

function add_item(item, count)
	if not windower.ffxi.get_info().logged_in then
		return
	end

    local player = windower.ffxi.get_player()
    notesdb:exec('INSERT OR REPLACE INTO itemwatch VALUES ("' .. player['name'] ..'","' .. player['main_job_id'] .. '","' .. player['sub_job_id'] .. '","' .. item .. '","' .. count .. '")')

	watched_items = get_items()
end

function remove_item(item)
	if not windower.ffxi.get_info().logged_in then
		return
	end

    local player = windower.ffxi.get_player()
    notesdb:exec('DELETE FROM itemwatch WHERE char = "' .. player['name'] ..'" AND mjob = "' .. player['main_job_id'] .. '" AND sjob = "' .. player['sub_job_id'] .. '" AND item = "' .. item .. '"')

	watched_items = get_items()
end

function remove_all_items()
	if not windower.ffxi.get_info().logged_in then
		return
	end

	local player = windower.ffxi.get_player()
    notesdb:exec('DELETE FROM itemwatch WHERE char = "' .. player['name'] ..'" AND mjob = "' .. player['main_job_id'] .. '" AND sjob = "' .. player['sub_job_id'] .. '"')

	watched_items = get_items()
end

function get_items()
	local itemlist = T{}
	if not windower.ffxi.get_info().logged_in then
		return itemlist
	end

    local player = windower.ffxi.get_player()
    local query = 'SELECT * FROM "itemwatch" WHERE char = "' .. player['name'] .. '" AND mjob = "' .. player['main_job_id'] .. '" AND sjob = "' .. player['sub_job_id'] .. '"'
        
    if notesdb:isopen() and query then
        for char,mjob,sjob,item,count in notesdb:urows(query) do
            table.insert(itemlist ,{['name']= item, ['quantity'] = count})
        end
    end
    return itemlist
end

windower.register_event('load', function()
    notesdb = sqlite3.open(windower.addon_path .. '/data/notes.db')
    notesdb:exec('CREATE TABLE IF NOT EXISTS itemwatch(char TEXT, mjob INTEGER, sjob INTEGER, item TEXT, count INTEGER)')
end)

windower.register_event('unload', function()
    notesdb:close()
end)

windower.register_event("load", "login", function()
    if not windower.ffxi.get_info().logged_in then
        return
    end

	watched_items = get_items()
end)

windower.register_event("job change", function(main_job_id)
	watched_items = get_items()
end)

windower.register_event('addon command', function(comm, ...)
	local args = L{...}
	comm = comm or 'help'
    comm = comm:lower()
	if comm == "help" or comm == "h" then
		local help = {
			('\\cs(%s)Addon commands:\\cr'):format('20,255,180'),
			(' %s\\cs(%s)//iw p <x> <y>\\cr\\cs(%s): Move the text element to given coordinates.\\cr'):format('':lpad(' ', 2), '100,200,100', '255,255,255'),
			(' %s\\cs(%s)//iw a <item>\\cr\\cs(%s): Add an item to be tracked.\\cr'):format('':lpad(' ', 2), '100,200,100', '255,255,255'),
			(' %s\\cs(%s)//iw a <item> <quantity>\\cr\\cs(%s): Track an item with color indicating running out.\\cr'):format('':lpad(' ', 2), '100,200,100', '255,255,255'),
			(' %s\\cs(%s)//iw r <item>\\cr\\cs(%s): Stop tracking an item.\\cr'):format('':lpad(' ', 2), '100,200,100', '255,255,255'),
			(' %s\\cs(%s)//iw c\\cr\\cs(%s): Clear all tracked items.\\cr'):format('':lpad(' ', 2), '100,200,100', '255,255,255'),
			(' %s\\cs(%s)//iw h\\cr\\cs(%s): Show this help text.\\cr'):format('':lpad(' ', 2), '100,200,100', '255,255,255'),
		}
		print(table.concat(help, '\n'))
	elseif comm == "add" or comm == "a" then
		if args[1] then
			local item_name = args[1]
			local limit = 1
			if args[2] then
				limit = tonumber(args[2])
			end
			add_item(item_name, limit)
		end
	elseif comm == "remove" or comm == "r" then
		if args[1] then
			local item_name = args[1]
			remove_item(item_name)
		end
	elseif comm == "clear" or comm == "c" then
		remove_all_items()
	elseif comm == "pos" or comm == "p" then
		settings.pos.x = tonumber(args[1] or 0)
		settings.pos.y = tonumber(args[2] or args[1] or 0)
		text_box:pos(settings.pos.x,settings.pos.y)
		local player = windower.ffxi.get_player()
		config.save(settings, player.name)
	elseif comm == "debug" or comm == "d" then
		table.vprint(settings)
		table.vprint(get_items())
	end
end)