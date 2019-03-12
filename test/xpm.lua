#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Test program for XPM file generator                                     |
|                                                                          |
|  Copyright(c) 2019 Andrew Cannon <ajc@gmx.net>                           |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local VERSION = 1
local REVISION = 0


require "geneas.getopt"
require "geneas.dprint"
require "geneas.dump"

local class = require "geneas.class"
local XPM = require "geneas.xpm"

local function heading()
	printf("%s version %d.%02d", arg[0], VERSION, REVISION)
end

local function fatal(stat, msg, ...)
	printf(msg, ...)
	os.exit(stat)
end

local function usage()
	heading()
	print("usage: lua "..arg[0].." ")
	print "options: "
	print "         -c <cpp>       xpm chars per pixel (default 3)"
	print "         -w <width>     width (default 512)"
	print "         -h <height>    height (default 512)"
	print "         -r <rotation>  ror\tate colours (0..2)"
	print "         -k <gradient>  range [0..1] default = 1"
	print "         -v             verbose"
	print "         -z             inc debug level"
end

-----------------

local rot = 0
local cpp = 3
local width = 512
local height = 512
local k
local args = {}
for opt,par, err in getopt(arg, "c:w:h:k:r:vz", true) do
	if opt == true then table.insert(args, par)
	elseif opt == "c" then cpp = par
	elseif opt == "w" then width = par
	elseif opt == "h" then height = par
	elseif opt == "r" then rot = par
	elseif opt == "k" then k = par
	elseif opt == "v" then verbose = true
	elseif opt == "z" then debug_level = debug_level + 1
	else usage(); fatal(1, "invalid option")
	end
end	

local file = args[1] or "test.xpm"
local xpm = XPM.new(file, width, height, cpp)

local min = math.min
local max = math.max

local m = {}
local ri = (0 + rot) % 3 + 1
local gi = (1 + rot) % 3 + 1
local bi = (2 + rot) % 3 + 1
for yy = 0, height - 1 do
	local y = yy / (height - 1.0)
	local my = {}
	for xx = 0, width - 1 do
		local x = xx / (width - 1.0)
		local c = not k
			and { y, x, 1 - max(x, y) }	-- k == 1
			or {
				min(1, y * (1/k - x*(1-k)/k)),
				min(1, x * (1/k - y*(1-k)/k)),
				min(1, x > y and (1 - x) * (1/(1-k) - y*k/(1-k)) or (1 - y) * (1/(1-k) - x*k/(1-k)))
			}
		
		my[xx + 1] = xpm:defcolour { r = c[ri], g = c[gi], b = c[bi], range = 1 }
	end
	m[yy + 1] = my
end
	
xpm:open()
for y = 1, height do
	xpm:putline(m[y])
end
xpm:close()

vprint "xpm test ok"
