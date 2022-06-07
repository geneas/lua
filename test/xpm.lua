#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Test program for XPM file generator                                     |
|                                                                          |
|  Copyright(c) 2019,2022 Andrew Cannon <ajc@gmx.net>                      |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local VERSION = 2
local REVISION = 0



require "geneas.getopt"
require "geneas.dprint"
require "geneas.dump"

local class = require "geneas.class"
local XPM = require "geneas.xpm"

local min = math.min
local max = math.max
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt
local atan = math.atan
local floor = math.floor

local function round(x) return floor(x + 0.5) end



local function heading()
	printf("%s version %d.%02d", arg[0], VERSION, REVISION)
end

local function fatal(stat, msg, ...)
	printf(msg, ...)
	os.exit(stat)
end

local function usage()
	heading()
	print("usage: lua " .. (arg[0] or "?") .. " [<output filename>]")
	print "options: "
	print "         -c <cpp>       xpm chars per pixel (default 3)"
	print "         -w <width>     width (default 512)"
	print "         -h <height>    height (default 512)"
	print "         -r <rotation>  rotate colours (0..2)"
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

local function generate(file, xy2colour)
	local xpm = XPM.new(file, width, height, cpp)
	local m = {}
	
	for yy = 0, height - 1 do
		local y = yy / (height - 1.0)
		local my = {}
		for xx = 0, width - 1 do
			local x = xx / (width - 1.0)
			local col
			
			local r, g, b = xy2colour(x, y)
			if type(r) == "number" then	-- assume RGB
				local rx, gx, bx = round(r * 255), round(g * 255), round(b * 255)
				if rx % 17 == 0 and gx % 17 == 0 and bx % 17 == 0 then
					col = string.format("#%x%x%x", rx / 17, gx / 17, bx / 17)
				else col = { r = r, g = g, b = b, range = 1 }
				end
			else
				col = r
			end
			
			my[xx + 1] = xpm:defcolour(col)
		end
		m[yy + 1] = my
	end
	
	-- all colours registered; write data
	xpm:open()
	for y = 1, height do
		xpm:putline(m[y])
	end
	xpm:close()
end	

-- colour indices for corner rotation:
local ri = (0 + rot) % 3 + 1
local gi = (1 + rot) % 3 + 1
local bi = (2 + rot) % 3 + 1

-- colour fade
local file1 = args[1] or "test1.xpm"
generate(file1, function(x, y)
		local c = not k
			and { y, x, 1 - max(x, y) }	-- k == 1
			or {
				min(1, y * (1/k - x*(1-k)/k)),
				min(1, x * (1/k - y*(1-k)/k)),
				min(1, x > y and (1 - x) * (1/(1-k) - y*k/(1-k)) or (1 - y) * (1/(1-k) - x*k/(1-k)))
			}
		
		return c[ri], c[gi], c[bi]
		
	end)


-- colour wheel	

local pi = math.pi
local pi2 = 2 * pi

local file2 = args[2] or "test2.xpm"
generate(file2, function(x, y)
		x = x * 2 - 1
		y = y * 2 - 1
		local r = sqrt(x * x + y * y)
		local a = ((atan(y, x) + pi) % pi2) / pi2
		if r > 1 then
			return "none"
		elseif r > 0.7 then
			return { type = "hsv", range = 1, h = a, v = (1 - r) / 0.3, s = 1 }
		else
			return { type = "hsv", range = 1, h = a, v = 1, s = r / 0.7 }
		end
	end)

vprint "xpm test ok"
