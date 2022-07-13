#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     camel.lua                                                   |
|  Function:   CamelCase Conversion Functions                              |
|  Created:    19:12:43  31 May  2015                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2015-2022 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local camel = {}
if _VERSION:match"Lua 5%.[12]" then
	module "camel"
	camel = _G.camel
end

local wrap = coroutine.wrap
local yield = coroutine.yield
local upper = string.upper
local insert = table.insert
local concat = table.concat


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
	return wrap(function()
			for g in s:gmatch "%w+" do
				local i = g:match "^%U+"
				if i then yield(i) end
				for w in g:gmatch "%u+%U*" do
					yield(w)
				end
			end
		end)
end

-- convert to camelCase
-- capital: if true then first letter is capitalized
function camel.to(s, capital)
	local subs = {}
	
	for elt in words(s) do
		insert(subs, capital and elt:lower():gsub("^.", upper) or elt:lower())
		capital = true
	end
	return concat(subs, "")
end

-- convert from camelCase to underscore_separated
function camel.from(s)
	local subs = {}
	
	for elt in words(s) do
		insert(subs, elt:lower())
	end
	return concat(subs, "_")
end


return camel
