#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     export.lua                                                  |
|  Function:   Export data structure in Lua-readable syntax                |
|  Created:    17:35:17  13 Aug  2005                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2005-2022 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

if _VERSION:match"Lua 5%.[12]" then
	module("export", package.seeall)
end

local gsub = string.gsub
local match = string.match
local format = string.format
local insert = table.insert
local concat = table.concat
local sort = table.sort

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

function _G.export(var)
	local done = {}
	local function exp(var)
		if type(var) == "string" then
			return (gsub(format("%q", var),"\\\n","\\n"))
		elseif type(var) == "table" then
			if done[var] then return "<loop>" end
			done[var] = true
			
			local out = {}
			
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
			
			local inext = 1
			
			for _, key in ipairs(keys) do
				local val = var[key]
				
				if key == inext then
					insert(out, exp(val))
					inext = inext + 1
				else
					local tag = key
					
					if type(key) ~= "string" or keywords[key]
							or not match(key, "^[%a_][%w_]*$") then
						tag = "[" .. exp(key) .. "]"
					end
					insert(out, tag .. "=" .. exp(val))
				end
			end
			return "{" .. concat(out, ",") .. "}"
		else return tostring(var)
		end
	end
	return exp(var)
end
