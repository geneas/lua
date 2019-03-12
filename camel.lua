#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     camel.lua                                                   |
|  Function:   CamelCase Conversion Functions                              |
|  Created:    19:12:43  31 May  2015                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2015-2019 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local camel = {}
if _VERSION:match"Lua 5%.[12]" then
	module("camel",package.seeall)
	camel = _G.camel
end

-- word iterator
--
-- a word consists of a sequence of alphanumeric characters delimited
-- by a) a transition from non-alphanumeric to alphanumeric or b) a
-- transition from lower case or numeric to upper case. This definition
-- recognizes words in either camel case or underscore-separated format
-- so it can be used for conversion in either direction. Note that all
-- punctuation and space characters are removed.
--
local function words(s)
	return coroutine.wrap(function()
			for g in s:gmatch"%w+" do
				local i = g:match"^%U+"
				if i then coroutine.yield(i) end
				for w in g:gmatch"%u+%U*" do
					coroutine.yield(w)
				end
			end
		end)
end

-- convert to camelCase
-- capital: if true then first letter is capitalized
function camel.to(s, capital)
	local subs = {}
	
	for elt in words(s) do
		table.insert(subs, capital and elt:lower():gsub("^.",string.upper) or elt:lower())
		capital = true
	end
	return table.concat(subs, "")
end

-- convert from camelCase to underscore_separated
function camel.from(s)
	local subs = {}
	
	for elt in words(s) do
		table.insert(subs, elt:lower())
	end
	return table.concat(subs, "_")
end


return camel
