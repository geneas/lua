#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     tabular.lua                                                 |
|  Function:   High-level Table Utilities                                  |
|  Created:    17:04:11  21 Jan  2012                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2012-present Andrew Cannon                                 |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

require "geneas.dprint"

local class = require "geneas.class"

local tabular = {}
if _VERSION:match"Lua 5%.[12]" then
	module("tabular", package.seeall)
	tabular = _G.tabular
end

-- use lua's own pqairs function internally
local pairs = _G.pairs

local wrap = coroutine.wrap
local yield = coroutine.yield
local gsub = string.gsub
local match = string.match
local format = string.format
local insert = table.insert
local concat = table.concat
local sort = table.sort

local classof = class.classof


local g_metamode_k  = { __mode = "k" }
local g_metamode_v  = { __mode = "v" }
local g_metamode_kv = { __mode = "kv" }

g_metamode_k.__metatable = g_metamode_k
g_metamode_v.__metatable = g_metamode_v
g_metamode_kv.__metatable = g_metamode_kv
	

-------------------------------------------------------------------------------
-- unify tables --
------------------
-- unify({ tables [,writable:bool] [,maxdepth:int] }, writable:bool, update:function)
--
local NIL = {}
local UNIFY = {}
local MAXDEPTH = 50 -- default

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
				error("unify: entry " .. i .. " is not a table")
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
		dprint "Maximum unification depth exceeded"
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
				return wrap(function()
						for key, value in pairs(getkeys()) do
							yield(key, type(value) == "table" and rv[key] or value)
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



-------------------------------------------------------------------------------
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


-------------------------------------------------------------------------------
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
	local fixed = { }
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
			if istable(value) and not fixed[value] then
				t[key] = fwd[value] or copy(value)
			else t[key] = value
			end
		end
		depth = depth - 1
		return t
	end
	
	return istable(tbl) and not fixed[tbl] and copy(tbl) or tbl
end


-------------------------------------------------------------------------------
-- export of arbitrary graph
----------------------------
-- returns a lua expression which, when executed, yields
-- a structure identical to the original structure
--
local keywords = {
	["and"]=true,		["break"]=true,	["do"]=true,
	["else"]=true,		["elseif"]=true,	["end"]=true,
	["false"]=true,	["for"]=true,		["function"]=true,
	["goto"]=true,
	["if"]=true,		["in"]=true,		["local"]=true,
	["nil"]=true,		["not"]=true,		["or"]=true,
	["repeat"]=true,	["return"]=true,	["then"]=true,
	["true"]=true,		["until"]=true,	["while"]=true
}

local function export(var, flags)
	--
	-- check flags, validate source tables & copy to internal
	--
	local opttab = type(flags) == "table" and flags or {}
	local optstr = type(flags) == "string" and flags or ""

	local load = opttab.load or (optstr:match"%f[%a]load%f[%A]")
	local pretty = opttab.pretty or (optstr:match"%f[%a]pretty%f[%A]")
	
	---[[<debug>
	local debug = opttab.debug or tonumber(optstr:match"%f[%a]debug=(%d+)")
	local debugsave = getDebugLevel()
	setDebugLevel(debug or 0)
	dprint("debug level " .. getDebugLevel())
	--]]
	
	local delim0 = pretty and "\n" or ""
	local delim1 = pretty and "\n" or " "
	local delim2 = pretty and "\n" or ";"
	
	local res = {}
	if load then insert(res, "return ") end
	
	-- return export of simple quantity or nil
	function exp0(var)
		local t = type(var)
		if t == "string" then
			return (gsub(format("%q", var),"\\\n","\\n"))
		elseif t ~= "table" then
			return tostring(var)
		elseif not istable(var) then	-- object?
			return var.export and var:export() or tostring(var)
		end 
	end
	
	local txt = exp0(var)
	if txt then
		insert(res, txt)		-- scalar
	else
		local desc = {}
		local seq = 0
		
		-- recursive scanning function for first pass (build descriptors)
		local function exp1(var, par, typ)
			local d = desc[var]
			if d then
				--[[<debug>
				if debug then
					local function parents(d)
						if not d.multi then return d.par and d.par.src[1] or "-" end
						local p = {}
						for k in pairs(d.par) do insert(p, tostring(k.src[1])) end
						return "{" .. concat(p, ",") .. "}"
					end
					printf("%s\t(%6s/ %s)\tname:%s act:%s sub:%s par:%s", var[1], typ or "isref", par.src[1], d.name, d.active, d.sub, parents(d))
				end--]]
				
				if d.active then
					-- parent reference is a loop
					-- make parent a subtable as well to simplify access during post
					-- do not record parent reference as the parent is obviously deeper
					d.sub = true
					par.sub = true
				elseif not d.multi then
					d.multi = true
					d.sub = true							-- multiply referenced; make subtable
					d.par = { [d.par] = true, [par] = true }
				else
					d.par[par] = true						-- yet another reference
				end
			else
				local refs = {}
				d = { src = var, par = par, seq = seq, active = true }
				desc[var] = d
				seq = seq + 1
				
				--[[<debug>
				if debug then
					printf("%s\t(%6s/ %s)\tname:%s", var[1], typ or "isref", par and par.src[1] or "-", d.name)
				end--]]
				
				-- always sort keys, so exports are well-defined
				--
				local keys = {}
				for key in pairs(var) do
					insert(keys, key)
				end
				sort(keys, function(k1, k2)
						local n1, n2 = type(k1) == "number", type(k2) == "number"
				
						if n1 then
							return not n2 or k1 < k2
						else
							return not n2 and tostring(k1) < tostring(k2)
						end
					end)
				
				-- scan subtables
				for _, k in ipairs(keys) do
					local v = var[k]
					if istable(k) then exp1(k, d, "iskey") end
					if istable(v) then exp1(v, d) end
				end
		
				local meta = getmetatable(var)
				if meta then d.meta = exp1(meta, d, "ismeta") end				
				
				d.keys = keys		-- save for pass 2
				d.active = nil
			end
			if typ then d[typ] = true end
			return d
		end
		
		-- build descriptor table
		local dtop = exp1(var)
		dtop.sub = true
		
		-- build an array of subtable descriptors		
		local tsub = {}
		for _, d in pairs(desc) do
			if d.sub then insert(tsub, d) end
		end
		
		-- recursive scanning function for second pass (generate output)
		local post = {}
		local seq = 0
		local function exp2(var, top)
			local txt = exp0(var)
			if txt then return txt
			else
				local out = {}
				local d = desc[var]
				
				if top then seq = d.seq end
				
				--d2printf("exp2:%d, name:%s", d.seq, d.name)--<debug>
				local function postpone(v, dv)
					dv = dv or desc[v]
					return dv and dv.sub and (dv.seq >= seq)
				end
				
				local meta = d.meta
				local postmeta = meta and postpone(nil, meta)
				if meta then
					--printf("%s: meta:%s post:%s", d.src[1], meta.src[1], postmeta)
					d.meta = nil
					insert(postmeta and post or out, "setmetatable(")
				end
				
				if not top and d.sub then
					insert(out, d.name)
				else
					local inext = 1		-- next sequential index
					local items = {}
					for _, key in ipairs(d.keys) do
						local dot = ""
						local val = var[key]
						
						local function outkey(dest, dot)
							local bits = {}
							
							--d2printf("outkey(%s,%s)", tostring(key), tostring(val))--<debug>
							if type(key) ~= "string" or keywords[key] or not match(key, "^[%a_][%w_]*$") then
								insert(bits, "[")
								insert(bits, exp2(key))
								insert(bits, "]=")
							else
								insert(bits, dot .. key .. "=")
							end
							insert(bits, exp2(val))
							insert(dest, concat(bits))
						end
						if postpone(key) or postpone(val) then	-- forward reference (loop); move to post-build code
							--d3print"post"
							insert(post, d.name)
							outkey(post, ".")
							insert(post, delim2)
						elseif key == inext then					-- next sequential index
							insert(items, exp2(val))				-- <val>
							inext = inext + 1
						else
							outkey(items, "")							-- <key> = <val>
						end
					end
					insert(out, "{")
					insert(out, concat(items, ","))
					insert(out, "}")
				end
				if postmeta then
					insert(post, d.name .. ",")
					insert(post, exp2(meta.src))
					insert(post, ")" .. delim2)
				elseif meta then
					insert(out, ",")
					insert(out, exp2(meta.src))
					insert(out, ")")
				end
				return concat(out)
			end
		end
		
		-- generate output
		if #tsub <= 1 then
			insert(res, exp2(var, true))	-- simple tree structure
		else
			-- complex structure (DAG or generalised graph):
			--
			res = {}								-- start afresh
			
			-- build a list of all subtable descriptors by following all parent links
			-- to the top of the tree. keep track of height of each subtable
			for _, d in ipairs(tsub) do
				--[[<debug>
				local dt = {}
				if debug then
					insert(dt, d.src[1] .. ": ")
				end--]]
				local height = 0
				local function follow(d)
					if not d then return
					elseif d.sub then
						--[[<debug>
						if debug then
							insert(dt, height .. ":" .. d.src[1] .. "(" .. (d.height and d.height or "-") .. ") ")
						end--]]
						if d.height and d.height >= height then return end	-- stop if already so high
						d.height = height
						height = height + 1
						if d.multi then
							for p in pairs(d.par) do follow(p) end
						elseif d.par then follow(d.par)
						end
						height = height - 1
					else follow(d.par)
					end
				end
				follow(d)
				--[[<debug>
				if debug then
					print(concat(dt))
				end--]]
			end
			
			-- sort subtable descriptor list according to height and sequence number
			-- ○ the lowest subtable will be built first
			-- ○ sequence number ensures that export is deterministic
			sort(tsub, function(d1, d2)
					local p1, p2 = d1.height, d2.height
					if p1 == p2 then return d1.seq < d2.seq
					else return p1 < p2
					end
				end)
				
			---[[<debug>
			if debug then
				for _, t in ipairs(tsub) do printf("height(%s):\t%d", tostring(t.src[1]), t.height) end
			end--]]
		
			-- assign build indices & subtable names
			for i, d in ipairs(tsub) do
				d.seq = i
				d.name = d.name or (d.iskey and "k" or d.ismeta and "m" or "t") .. i
			end
		
			if not load then insert(res, "(function()" .. delim1) end
			
			-- build all tables
			local rexp
			for _, d in ipairs(tsub) do
				local texp = exp2(d.src, true)
				
				rexp = (d == dtop) and #post == 0	-- last table can be returned directly
				
				if rexp then
					insert(res, "return " .. texp)
				else
					insert(res, "local " .. d.name .. "=")
					insert(res, texp)
					insert(res, delim2)
				end
			end
			
			-- add post-build assignments if any
			insert(res, concat(post))
			
			if not rexp then
				insert(res, "return " .. dtop.name)
			end
			if not load then insert(res, delim1 .. "end)()") end
		end
		insert(res, delim0)
	end
	---setDebugLevel(debugsave)--<debug>
	return concat(res)
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

tabular.export				= export


return tabular
