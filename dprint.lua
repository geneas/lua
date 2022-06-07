#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     dprint.lua                                                  |
|  Function:   Print Functions with Debug Level Control                    |
|  Created:    17:04:11  13 Aug  2005                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2005-2022 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

if _VERSION:match"Lua 5%.[12]" then
	module("dprint",package.seeall)
end

local format = string.format
local gmatch = string.gmatch
local match = string.match
local gsub = string.gsub
local sub = string.sub
local rep = string.rep
local concat = table.concat
local insert = table.insert
local max = math.max
local write = io.write
local flush = io.flush
local stdout = io.stdout
local date = os.date


_G.debug_level = _G.debug_level or 0

function _G.setDebugLevel(n) if n then _G.debug_level = n end return debug_level end
function _G.incDebugLevel() _G.debug_level = _G.debug_level + 1 end
function _G.decDebugLevel() _G.debug_level = max(0, _G.debug_level - 1) end
function _G.getDebugLevel() return _G.debug_level end
function _G.setVerbose(t) _G.verbose = type(t) ~= "boolean" or t end
function _G.getVerbose() return _G.verbose end

local function _print(...)
	local out = {}
	local pad = ""
	local dlm
	
	for _, s in ipairs {...} do
		if not dlm and _G.debug_header then
			dlm = date(gsub(_G.debug_header, "%%[%@%?]", { ["%@"] = level, ["%?"] = _G.debug_level }))
			pad = rep(' ', #dlm)
		end
		for line, eol in gmatch(tostring(s), "([^\n]*)(\n*)") do
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
	if #out > 0 and match(out[#out], "\b$") then
		out[#out] = sub(out[#out], 1, -2)
	else
		insert(out, '\n')
	end
	
	local msg = concat(out, "")
	
	if _G.debug_writer then
		_G.debug_writer(msg)
	else
		write(msg)
		flush(stdout)
	end
end

local function _dprint(level, ...)
	if _G.debug_level >= level then _print(...) end
end

-- formatted output
local function _printf(s, ...)
	_print(format(s, ...))
end

local function _dprintf(level, s, ...)
	if _G.debug_level >= level then _printf(s, ...) end
end
	
	
-- API	
------

-- override global print?
--_G.print = _print	-- ? not always desirable!

_G.printf =	_printf

-- debug fns
function _G.d0print(...)		_dprint(0, ...)		end
function _G.d1print(...)		_dprint(1, ...)		end
function _G.d2print(...)		_dprint(2, ...)		end
function _G.d3print(...)		_dprint(3, ...)		end
function _G.d4print(...)		_dprint(4, ...)		end
function _G.d5print(...)		_dprint(5, ...)		end
function _G.d6print(...)		_dprint(6, ...)		end
function _G.d7print(...)		_dprint(7, ...)		end
function _G.dnprint(n, ...)	_dprint(n, ...)		end

function _G.d0printf(s, ...)		_dprintf(0, s, ...) end
function _G.d1printf(s, ...)		_dprintf(1, s, ...) end
function _G.d2printf(s, ...)		_dprintf(2, s, ...) end
function _G.d3printf(s, ...)		_dprintf(3, s, ...) end
function _G.d4printf(s, ...)		_dprintf(4, s, ...) end
function _G.d5printf(s, ...)		_dprintf(5, s, ...) end
function _G.d6printf(s, ...)		_dprintf(6, s, ...) end
function _G.d7printf(s, ...)		_dprintf(7, s, ...) end
function _G.dnprintf(n, s, ...)	_dprintf(n, s, ...) end

-- for compatibility
_G.dprint = _G.d1print
_G.dprintf = _G.d1printf

-- verbose fns
function _G.vprint(...)	if _G.verbose then _print(...) end end
function _G.vprintf(s, ...) if _G.verbose then _printf(s, ...) end end

-- error fn
function _G.errorf(s, ...) error(format(s, ...)) end
