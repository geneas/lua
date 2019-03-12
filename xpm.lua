#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     xpm.lua                                                     |
|  Function:   Class to generate XPM Image files                           |
|  Created:    19:03:26  11 Dec  2018                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2018-2019 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local xpm = {}
if _VERSION:match"Lua 5%.[12]" then
	module("xpm",package.seeall)
	xpm = _G.xpm
end

local class = require "geneas.class"

local type = _G.type
local ipairs = _G.ipairs
local tostring = _G.tostring

local abs = math.abs
local min = math.min
local max = math.max
local floor = math.floor
local ioopen = io.open
local rep = string.rep
local byte = string.byte
local char = string.char
local format = string.format
local insert = table.insert
local concat = table.concat
local unpack = table.unpack or function(t)
		local function nxt(i)
			local v = t[i]
			if v then return v, nxt(i + 1) end
		end
		return nxt(1)
	end


-- class XPM
------------
local c_first = '0'
local c_last = 'z'
local c_spec = '["\\?]'

local function initialize(_, name, width, height, cpp)
	return type(name) == "table" and name or { name = name, width = width, height = height, cpp = cpp or 1 }
end
local function _nextsymbol(this)
	local ctab = this._colours
	local symbol = ctab.next
	
	if not symbol then error "XPM: no more colours" end
	
	local next = { byte(symbol, 1, -1) }
	
	for p = #next, 1, -1 do
		if char(next[p]) == c_last then
			next[p] = byte(c_first)
			if p == 1 then
				next = nil
				break
			end
		else
			repeat
				next[p] = next[p] + 1
			until not char(next[p]):match(c_spec)
			break		
		end
	end
	ctab.next = next and char(unpack(next))
	
	return symbol
end
local function defcolour(this, colour, symbol)
	if type(colour) == "table" then
		local r, g, b
		
		if colour.type == "hsv" then
			local range = colour.range or 255
			local h = colour.h * 1.0 / (colour.hrange or range)
			local s = colour.s * 1.0 / range
			local v = colour.v * 255.0 / range
			
			r = (min(1, max(0, abs(h * 6 - 3) - 1)) * s + (1.0 - s)) * v
			g = (min(1, max(0, 2 - abs(h * 6 - 2))) * s + (1.0 - s)) * v
			b = (min(1, max(0, 2 - abs(h * 6 - 4))) * s + (1.0 - s)) * v
		else
			-- RGB
			r = colour.r
			g = colour.g
			b = colour.b
			
			local range = colour.range
			
			if range then			
				r = r * 255.0 / range
				g = g * 255.0 / range
				b = b * 255.0 / range
			end
		end
		colour = format('#%02X%02X%02X', floor(r + 0.5), floor(g + 0.5), floor(b + 0.5))
	elseif type(colour) ~= "string" or not colour:match"#%x%x%x%x%x%x" then
		error("XPM: invalid colour: " .. tostring(colour))
	end
	
	local ctab = this._colours
	
	if not ctab then
		ctab = { next = rep(c_first, this.cpp), index = {} }
		this._colours = ctab
	end
	if symbol then
		if #symbol ~= this.cpp then error("XPM: invalid symbol size for '" .. symbol .. "'") end
		
		local c = ctab.index[symbol]
		
		if not c then
			ctab.index[symbol] = colour
			ctab[colour] = symbol				-- save latest symbol for colour
			insert(ctab, symbol)					
		elseif c ~= colour then
			error("XPM: colour conflict for symbol '%s'", symbol)
		end
	else
		symbol = ctab[colour]
		if not symbol then
			symbol = _nextsymbol(this)
			ctab.index[symbol] = colour
			ctab[colour] = symbol
			insert(ctab, symbol)
		end
	end
	return symbol
end
local function writeheader(this)
	this._fd:write(format('/* XPM */\nstatic char * XFACE[] = {\n"%d %d %d %d",\n',
											this.width, this.height, #this._colours, this.cpp))
	for i = 1, #this._colours do
		local c = this._colours[i]
		
		this._fd:write(format('"%s c %s",\n', c, this._colours.index[c]))
	end
end
local function open(this, name, width, height)
	if type(name) == "string" then this.name = name end
	if width then this.width = tonumber(width) end
	if height then this.height = tonumber(height) end
	
	this._fd = ioopen(this.name, "w")
	this._line = {}
	writeheader(this)
end
local function putpixel(this, pix)
	insert(this._line, pix)
end
local function putline(this, line)
	local str1 = ""
	local str2 = ""
	
	if this._line[1] then
		str1 = concat(this._line, "")
		this._line = {}
	end
	if type(line) == "table" then
		str2 = concat(line, "")
	elseif line then
		str2 = line
	end
	
	this._fd:write(format('"%s%s",\n', str1, str2))
end
local function close(this)
	this._fd:write'};\n'
	this._fd:close()
	this._fd = nil
end

xpm.name = "xpm"
xpm.init = initialize
xpm.new = function(...) return xpm(...) end
xpm.__index = {
	defcolour = defcolour,
	putpixel = putpixel,
	putline = putline,
	open = open,
	close = close,
}

return class(xpm)

