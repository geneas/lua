#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     dprint.lua                                                  |
|  Function:   Print Functions with Debug Level Control                    |
|  Created:    17:04:11  13 Aug  2005                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2005-2019 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

if _VERSION:match"Lua 5%.[12]" then
	module("dprint",package.seeall)
end

local date = os.date
local concat = table.concat
local insert = table.insert
local write = io.write
local flush = io.flush
local stdout = io.stdout

_G.debug_level = _G.debug_level or 0

function _G.setDebugLevel(n) if n then _G.debug_level = n end return debug_level end
function _G.incDebugLevel() _G.debug_level = _G.debug_level + 1 end
function _G.decDebugLevel() _G.debug_level = math.max(0, _G.debug_level - 1) end
function _G.getDebugLevel() return _G.debug_level end
function _G.setVerbose(t) _G.verbose = type(t) ~= "boolean" or t end
function _G.getVerbose() return _G.verbose end

local function _dprint(level, ...)
	if _G.debug_level < level then return end
	
	local out = {}
	local pad = ""
	local dlm
	
	for _, s in ipairs {...} do
		if not dlm and _G.debug_header then
			dlm = date(_G.debug_header:gsub("%%[%@%?]", { ["%@"] = level, ["%?"] = _G.debug_level }))
			pad = string.rep(' ', #dlm)
		end
		for line, eol in tostring(s):gmatch"([^\n]*)(\n*)" do
			if dlm then
				insert(out, dlm)
				dlm = nil
			end
			if line ~= "" then
				insert(out, line)
			end
			if eol ~= "" then
				insert(out, eol)
				dlm = pad
			end
		end
		dlm = dlm or "\t"
	end
	insert(out, '\n')
	
	local msg = concat(out, "")
	
	if _G.debug_writer then
		_G.debug_writer(msg)
	else
		write(msg)
		flush(stdout)
	end
end

--function _G.print(...)	-- ? not always desirable!
--	_dprint(0, arg)
--end

function _G.d0print(...)	_dprint(0, ...)		end
function _G.d1print(...)	_dprint(1, ...)		end
function _G.d2print(...)	_dprint(2, ...)		end
function _G.d3print(...)	_dprint(3, ...)		end
function _G.d4print(...)	_dprint(4, ...)		end
function _G.d5print(...)	_dprint(5, ...)		end
function _G.d6print(...)	_dprint(6, ...)		end
function _G.d7print(...)	_dprint(7, ...)		end

-- for compatibility
_G.dprint = d1print


function _G.printf(s, ...)	_G.print(string.format(s, ...)) end
function _G.dprintf(s, ...)	_G.dprint(string.format(s, ...)) end
function _G.d1printf(s, ...)	_G.d1print(string.format(s, ...)) end
function _G.d2printf(s, ...)	_G.d2print(string.format(s, ...)) end
function _G.d3printf(s, ...)	_G.d3print(string.format(s, ...)) end
function _G.d4printf(s, ...)	_G.d4print(string.format(s, ...)) end
function _G.d5printf(s, ...)	_G.d5print(string.format(s, ...)) end
function _G.d6printf(s, ...)	_G.d6print(string.format(s, ...)) end
function _G.d7printf(s, ...)	_G.d7print(string.format(s, ...)) end

function _G.vprint(...)	if _G.verbose then _dprint(0, ...) end end
function _G.vprintf(s, ...) if _G.verbose then _dprint(0, string.format(s, ...)) end end
