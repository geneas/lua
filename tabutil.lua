#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     tabutil.lua                                                 |
|  Function:   Table Utilities                                             |
|  Created:    17:04:11  21 Jan  2012                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2012-present Andrew Cannon                                 |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local tabutil = {}
if _VERSION:match"Lua 5%.[12]" then
	module("tabutil",package.seeall)
	tabutil = _G.tabutil
end

local format = string.format
local insert = table.insert
local sort = table.sort

local type = _G.type
local pairs = _G.pairs
local tonumber = _G.tonumber

local MAXDEPTH = 50 -- default


-- general utility functions
--

-- get table entry, set to default value if not existent
local function mkentry(tab, key, def)
	local v = tab[key]
	
	if v == nil then
		v = def
		tab[key] = v
	end
	return v
end

-- copy table (single level)
local function clone(t, withmeta)
	local r = {}
	
	for k, v in pairs(t) do
		r[k] = v
	end
	if withmeta then setmetatable(r, getmetatable(t)) end
	return r
end

-- merge t2 into t1
local function merge(t1, t2)
	for k, v in pairs(t2) do
		t1[k] = v
	end
	return t1
end

-- topup t1 from merge t2 - copy only entries which do not already exist
local function topup(t1, t2)
	for k, v in pairs(t2) do
		if t1[k] == nil then t1[k] = v end
	end
	return t1
end

-- remove all keys in t2 from t1
local function remove(t1, t2)
	for k in pairs(t2) do
		t1[k] = nil
	end
	return t1
end

-- remove keys from t1 that are not also in t2 (ignoring value)
local function keep(t1, t2)
	for k in pairs(t1) do
		if t2[k] == nil then
			t1[k] = nil
		end
	end
	return t1
end

-- map a function over an associative array
local function mapa(t, f)
	local r = {}
	
	for k, v in pairs(t) do
		r[k] = f(v)
	end
	return r
end


-- list operations
--
local function map(t, f)
	local r = {}
	
	for k, v in ipairs(t) do
		r[k] = f(v)
	end
	return r
end

local function foldl(t, f, r)
	for _, v in ipairs(t) do
		r = f(r, v)
	end
	return r
end

local function foldr(t, f, r)
	for i = #t, 1, -1 do
		r = f(t[i], r)
	end
	return r
end

local function filter(t, f)
	local r = {}
	
	for _, v in ipairs(t) do
		if f(v) then
			insert(r, v)
		end
	end
	return r
end

local function reverse(t)
	local e = #t + 1
	local r = {}
	
	for i = 1, e do
		r[i] = t[e - i]
	end
	return r
end

local function take(t, n)
	local r = {}
	
	for i = 1, n do
		r[i] = t[i]
	end
	return r
end

local function drop(t, n)
	local r = {}
	
	for i = n + 1, #t do
		insert(r, t[i])
	end
	return r
end

-- rotate n places to the left
local function rotate(t, n)
	local r = {}
	local c = #t
	local j = 1 + math.floor(n % c)
	
	for i = 1, c do
		r[i] = t[j]
		j = j == c and 1 or j + 1
	end
	return r
end

-- append to existing table
local function append(t1, t2)
	for _, v in ipairs(t2) do
		insert(t1, v)
	end
	return t1
end

	
-- table comprehension
--
-- p is a table containing some lists
-- f is optional guard/mapping function (default is identity fn)
--
-- index #p changes fastest, non-numerical indices change slowest
-- f is called with a table containing one value from each member of p
-- the returned value is inserted into the comprehension if not nil
--
local function comprehend(p, f)
	local tabs = {}
	
	repeat
		local keys = {}
	
		for k, t in ipairs(p) do
			keys[k] = true
			if t[1] ~= nil then
				insert(tabs, 1, { i = 1, n = #t, t = t, k = k })
			end
		end
		for k, t in pairs(p) do
			if not keys[k] and t[1] ~= nil then
				insert(tabs, { i = 1, n = #t, t = t, k = k })
			end
		end
	until true
	
	local r = {}
	
	while true do
		-- build next raw value
		local v = {}
		
		for _, t in ipairs(tabs) do
			v[t.k] = t.t[t.i]
		end
		if type(f) == "function" then v = f(v) end	-- call function if any
		if v ~= nil then insert(r, v) end				-- insert into comprehension
		
		-- increment index
		for k, t in ipairs(tabs) do
			t.i = t.i + 1
			if t.i <= t.n then break end
			if k == #tabs then
				return r					-- finished... return result
			end
			t.i = 1
		end
	end
end


-- typed/table compare to specified depth
--
local function tcompare(t1, t2, depth)
	if type(t1) ~= type(t2) then
		return false
	end
	if type(t1) ~= "table" or depth == 0 then
		return t1 == t2
	end
	
	local done = {}
	
	for k, v in pairs(t1) do
		if not tcompare(v, t2[k], depth and depth - 1 or MAXDEPTH - 1) then
			return false
		end
		done[k] = true
	end
	for k, _ in pairs(t2) do
		if not done[k] then
			return false
		end
	end
	return true
end

-- numeric sort
local function numericlt(a, b)
	--
	-- numeric sort - numeric substrings are sorted in
	-- numerical order rather than alphabetical order.
	--
	local function section(s)
		local a, b, c = s:match"^(%D*)(%d*)(.*)$"
		if a ~= "" then
			return a, b .. c
		else
			return tonumber(b), c
		end
	end
	local p, q, lt
	
	repeat
		p, a = section(a)
		q, b = section(b)
		if type(p) ~= "number" or type(q) ~= "number" then
			p, q = tostring(p), tostring(q)
		end
		lt = p < q
	until p ~= q or (a == "" and b == "")
	return lt
end


-- sorted pairs
local function spairs(tbl, flags)
	return coroutine.wrap(function()
			local opttab = type(flags) == "table" and flags or {}
			local optstr = type(flags) == "string" and flags or ""
			local reverse = opttab.reverse or (optstr:match"%f[%a]reverse%f[%A]")
			local numeric = opttab.numeric or (optstr:match"%f[%a]numeric%f[%A]")
			local filter = opttab.filter or (optstr:match"%f[%a]filter=([^;]+)")
			local compare = opttab.compare

			if type(filter) == "string" then
				local pattern = "^" .. filter .. "$"
				
				filter = function(k) return k:match(pattern) end
			end
			
			-- find all sortable keys (string & numeric)
			local keys = {}
			local keymap = {}
			
			for k, v in pairs(tbl) do
				if type(k) == "string" or type(k) == "number" then
					insert(keys, k)
					keymap[k] = true
				end
			end
			
			-- sort keys
			sort(keys, compare or function(a, b)
					local lt
					
					if type(a) == "number" and type(b) == "number" then
						lt = a < b
					elseif type(a) == "number" then
						lt = true						-- number < string
					elseif type(b) == "number" then
						lt = false
					elseif numeric then
						lt = numericlt(a, b)
					else
						lt = a < b
					end
					if reverse then lt = not lt end
					return lt
				end)
			
			for _, k in ipairs(keys) do
				if not filter or filter(k) then
					coroutine.yield(k, tbl[k])
				end
			end
			for k, v in pairs(tbl) do
				if not keymap[k] and (not filter or filter(k)) then
					coroutine.yield(k, v)
				end
			end
		end)
end


-- iterator utilities
--

-- return results of an iterator in a table
local function gtable(iter, state, value)
	local r = {}
	
	while true do
		value = iter(state, value)
		if not value then break end
		table.insert(r, value)
	end
	return r
end

-- return results of a two-valued iterator in a table
local function g2table(iter, state, value)
	local r = {}
	
	while true do
		local value2
		
		value, value2 = iter(state, value)
		if not value then break end
		table.insert(r, value2)
	end
	return r
end

-- return results of an iterator inline
local function ginline(iter, state, value)
	local function step()
		value = iter(state, value)
		if value then return value, step() end
	end
	return step()
end

-- return results of a two-valued iterator inline
local function g2inline(iter, state, value)
	local function step()
		local value2
		
		value, value2 = iter(state, value)
		if value then return value2, step() end
	end
	return step()
end

-- return iterator which yields all values in array (no keys)
local function ivalues(t)
	local f, s, k, v = ipairs(t)
	
	return function()
		k, v = f(s, k)
		return v
	end
end



-- module tabutil:

tabutil.mkentry			= mkentry
tabutil.clone				= clone
tabutil.merge				= merge
tabutil.topup				= topup
tabutil.remove				= remove
tabutil.keep				= keep
tabutil.mapa				= mapa

tabutil.map					= map
tabutil.foldl				= foldl
tabutil.foldr				= foldr
tabutil.filter				= filter
tabutil.reverse			= reverse
tabutil.take				= take
tabutil.drop				= drop
tabutil.append				= append
tabutil.rotate				= rotate
tabutil.comprehend		= comprehend

tabutil.tcompare			= tcompare
tabutil.numericlt			= numericlt
tabutil.spairs				= spairs
	
tabutil.gtable				= gtable
tabutil.g2table			= g2table
tabutil.ginline			= ginline
tabutil.g2inline			= g2inline

tabutil.ivalues			= ivalues

return tabutil
