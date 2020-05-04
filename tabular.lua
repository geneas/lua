#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     tabular.lua                                                 |
|  Function:   High-level Table Utilities                                  |
|  Created:    17:04:11  21 Jan  2012                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2012-2019 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local tabular = {}
if _VERSION:match"Lua 5%.[12]" then
	module("tabular",package.seeall)
	tabular = _G.tabular
end

require "geneas.dprint"

local format = string.format
local insert = table.insert
local sort = table.sort

local class = require "geneas.class"
local classof = class.classof


local g_metamode_k  = { __mode = "k" }
local g_metamode_v  = { __mode = "v" }
local g_metamode_kv = { __mode = "kv" }

g_metamode_k.__metatable = g_metamode_k
g_metamode_v.__metatable = g_metamode_v
g_metamode_kv.__metatable = g_metamode_kv

local type = _G.type
local pairs = _G.pairs
local error = _G.error
local tonumber = _G.tonumber
	

-- unify tables --
------------------
-- unify({ tables [,writable:bool] [,maxdepth:int] }, writable:bool, update:function)
--
local NIL = {}
local UNIFY = {}
local MAXDEPTH = 50

local function istable(v)
	return type(v) == "table" and v ~= NIL and classof(v) == nil
end
local function isvalue(v)
	return v ~= nil and type(v) ~= "table" or v == NIL or classof(v) ~= nil
end

local function unify(tables, flags)
	if not tables.control then
		--
		-- top-level unification (user call)
		-- check flags, validate source tables & copy to internal
		--
		local opttab = type(flags) == "table" and flags or tables	-- allow options in tables parameter
		local optstr = type(flags) == "string" and flags or ""
	
		local maxdepth = opttab.maxdepth or tonumber(optstr:match"%f[%a]maxdepth=(%d+)") or type(flags) == "number" and flags
		local writable = opttab.writable or (optstr:match"%f[%a]writable%f[%A]") or type(flags) == "boolean" and flags
		local relaxed = opttab.relaxed or (optstr:match"%f[%a]relaxed%f[%A]")
		
		local ts = {
			toplevel = true,
			maxdepth = maxdepth or MAXDEPTH,
			control = {
				writable = writable,
				relaxed = relaxed,
				map = setmetatable({}, g_metamode_k)
			}
		}
		
		for i, t in ipairs(tables) do
			if type(t) ~= "table" then
				error("unify: entry "..i.." is not a table")
			end
			ts[i] = t
		end
	
		if writable then
			if not ts[1] then error "unify: cannot write to empty unification" end
			
			ts.wtable = ts[1]
			
			-- create top-level mask (deletion) table and insert in second place (after write table)
			--
			ts.dtable = {}
			insert(ts, 2, ts.dtable)
		end
		
		tables = ts		-- use internal copy
	end
	
	local maxdepth = tables.maxdepth
	local control = tables.control
	local update = tables.update
	local wtable = tables.wtable
	
	local function override(key, value)
		if wtable then
			wtable[key] = value
		elseif update then
			return update(key, value)
		else
			error "unify: cannot write to read-only unification"
		end
	end
	local function getkeys()
		-- build 'flat' table of keys & values for this level
		local keys = {}
		
		for i = #tables, 1, -1 do	-- scan from last to first
			for key, value in pairs(tables[i]) do
				if value == NIL then
					keys[key] = nil
				else
					keys[key] = value
				end
			end
		end
		return keys
	end
	local function getnumerickeys()
		-- build 'flat' table of numeric keys for this level
		local keys = {}
		
		for i = #tables, 1, -1 do	-- scan from last to first
			for key, value in pairs(tables[i]) do
				if type(key) == "number" then
					keys[key] = true
				end
			end
		end
		return keys
	end
	
	if maxdepth == 0 then
		-- just combine keys (note: will no longer be write protected!)
		dprint"Maximum unification depth exceeded"
		return getkeys(tbl)
	end
	
	-- maintain map from source set to unification
	--
	-- this ensures that multiple accesses to unified table values return the same result
	-- ...otherwise functions like deepcopy will not be able to detect loops
	--
	-- first build the n-dimensional index, where n is the size of the source set (#tables)
	--
	local mapref = control.map
	
	for i, t in ipairs(tables) do
		if t ~= dtable then
			local ref = mapref[t]
			
			if not ref then
				ref = setmetatable({}, g_metamode_k)
				mapref[t] = ref
			end
			mapref = ref
		end
	end
	
	local tg = mapref.target
	local rv = tg and tg.unify
	
	if rv then
		return rv	-- already unified this source set, return previous value
	end
	
	-- create a new unification
	-- note: it is only cached in the map as long as it is referenced from outside
	rv = {}
	mapref.target = setmetatable({ unify = rv }, g_metamode_v)
	
	local writable = control.writable
	local relaxed = control.relaxed
	local dtable = tables.dtable
	
	local umeta
	umeta = {
		__index = function(tbl, key)
				if key == UNIFY then return true end	-- special key to test whether table is a unification
				for i, t in ipairs(tables) do				-- scan component tables until a value for this key is found
					local value = t[key]
					
					if value ~= nil then
						if value == NIL then
							value = nil							-- NIL forces a value of nil
						elseif type(value) == "table" then
							-- return unification of all table values with this key
							local tbl = { value }
							
							for j = i + 1, #tables do		-- iterate over remaining tables
								local v = tables[j][key]
								
								if istable(v) then
									insert(tbl, v)
								elseif v ~= nil then break	-- scalar shadows further tables(?)
								end
							end
							
							if relaxed and #tbl == 1 then
								--
								-- in relaxed mode we may optimize away a unification
								-- containing only one table in certain circumstances.
								--
								if not writable then
									--
									-- relaxed means that write protection is not required, so
									-- we can assume that the source table will not be written to.
									--
									return value
								elseif i == 1 then
									--
									-- the first table can be written to in any case
									--
									return value
								end
							end
							
							tbl.maxdepth = maxdepth - 1
							tbl.control = control
							if writable then
								tbl.update = function(newkey, newvalue)
										override(key, { [newkey] = newvalue })
									end
								tbl.wtable = wtable and (i == 1) and wtable[key] or nil
								tbl.dtable = dtable[key]
								
								-- note: if wtable is present then dtable must be second, else first
								if not tbl.dtable then
									dtable[key] = {}
									tbl.dtable = dtable[key]
									insert(tbl, (tbl.wtable and 2 or 1), tbl.dtable)
								end
							end
							
							value = unify(tbl)
						end
						return value
					end
				end
			end,
			
		__newindex = function(tbl, key, value)
				override(key, value)
				dtable[key] = NIL
			end,
			
		__pairs = function()
				return coroutine.wrap(function()
						for key, value in pairs(getkeys()) do
							coroutine.yield(key, type(value) == "table" and rv[key] or value)
						end
					end)
			end,
			
		__len = function(tbl)
				return #getnumerickeys()
			end,
		
		__call = function(f, op)
				if op == "pairs" then return umeta.__pairs()
				elseif op == "mask" then return dtable
				end
				
				return {		-- info table
					control = control,
					wtable = wtable,
					dtable = dtable,
					tables = getDebugLevel() > 0 and tables or nil,
				}
			end,
	}
	umeta.__metatable = umeta

	return setmetatable(rv, umeta)
end

local function isunification(t)
	return type(t) == "table" and t[UNIFY]
end

-- pairs function for unifications with lua < 5.3
--
local function upairs(t)
	if isunification(t) then
		return t("pairs")
	else
		return pairs(t)
	end
end

-- structured indexing
----------------------
-- name is an index in 'flat' form, eg "m1.m2[3][1].m3[2]"
-- ...intermediate tables will be created as required

local function putfield(tab, name, data)
	local t = tab
	local ndx
	local function push(index)
		if ndx then
			if not istable(t[ndx]) then
				t[ndx] = {}		-- force table
			end
			t = t[ndx]
		elseif not istable(t) then
			tab = {}
			t = tab
		end
		ndx = index
	end
	
	for segment in name:gmatch"[^%.]+" do
		local member, indices = segment:match"^([^%[]*)%[([%d%[%],]+)%]$"
		
		if member then
			if member ~= "" then
				push(member)
			end
			for index in indices:gmatch"%d+" do 
				push(tonumber(index))
			end
		else
			push(segment)
		end
	end
	if ndx then
		t[ndx] = data
	else
		tab = data
	end
	return tab
end

local function getfield(tab, name)
	local t = tab
	
	for segment in name:gmatch"[^%.]+" do
		if not istable(t) then return end
		
		local member, indices = segment:match"^([^%[]*)%[([%d%[%],]+)%]$"
		
		if member then
			if member ~= "" then
				t = t[member]
			end
			for index in indices:gmatch"%d+" do 
				if not istable(t) then return end
				t = t[tonumber(index)]
			end
		else
			t = t[segment]
		end
	end
	if t == NIL then t = nil end
	return t
end

-- return field names
local function fields(tab, maxdepth, selector)
	local r = {}
	local depth = 1
	local function scan(t, name)
		if not istable(t) or maxdepth and depth > maxdepth then
			if not selector or name:match(selector) then
				insert(r, name)
			end
		else
			local keys = {}
		
			depth = depth + 1
			for k, v in ipairs(t) do
				keys[k] = true
				scan(v, (name or "") .. "[" .. k .. "]")
			end
			for k, v in pairs(t) do
				if not keys[k] then
					if type(k) == "number" then
						scan(v, (name or "") .. "[" .. k .. "]")
					elseif type(k) == "string" then
						scan(v, (name and name .. "." or "") .. format("%q", k):sub(2, -2))
					else -- ignore
					end
				end
			end
			depth = depth - 1
		end
	end
	
	scan(tab)
	return r
end


-- deep copy of an arbitrary network
------------------------------------
-- checks for loops and recombinations
-- mapping tables can be returned to caller in map
-- ctrl specifies tables which are to be shared rather than copied
--
local function deepcopy(tbl, map, ctrl)
	-- prepare
	map = map or {}
	if not map.fwd then map.fwd = setmetatable({}, g_metamode_kv) end
	
	local fwd = map.fwd
	local fixed = { [NIL] = true }
	local depth = 0
	
	if ctrl then
		setmetatable(fixed, {
				__index = type(ctrl) == "function" and function(tbl, key) return ctrl(key) end
						or type(ctrl) == "number" and function(tbl, key) return depth > ctrl end
						or type(ctrl) ~= "table" and error "invalid control parameter"
						or (function()												-- list of fixed tables
							local t = {}
							for _,v in ipairs(ctrl) do t[v] = true end
							return function(tbl, key) return t[key] end
						end)()
			})
	end
	
	-- copy a table
	local function copy(tbl)
		local t = {}
		
		fwd[tbl] = t
		depth = depth + 1
		for key, value in pairs(tbl) do
			if type(value) == "table" and not fixed[value] then
				t[key] = fwd[value] or copy(value)
			else t[key] = value
			end
		end
		depth = depth - 1
		return t
	end
	
	return type(tbl) == "table" and not fixed[tbl] and copy(tbl) or tbl
end


-- module tabular:

tabular.NIL					= NIL
tabular.unify 				= unify
tabular.isunification	= isunification
tabular.istable			= istable
tabular.isvalue			= isvalue
tabular.upairs				= upairs	

tabular.putfield 			= putfield
tabular.getfield 			= getfield
tabular.fields				= fields	

tabular.deepcopy 			= deepcopy
	
return tabular
