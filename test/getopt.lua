#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Test suite for Option Processing Module                                 |
|                                                                          |
|  Copyright(c) 2019 Andrew Cannon <ajc@gmx.net>                           |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------
--
-- 02:10:24  18 Jan  2019 - ajc

require "geneas.getopt"
require "geneas.dprint"
require "geneas.export"

-- bootstrap!
for _,a in ipairs(arg) do
	if a == "-z" then _G.debug_level = 1 end
	if a == "-v" then _G.verbose = true end
end

local q = {
	"prog",
	"glub",
	"-abxyz",
	"-dcval",
	"squnz",
	"-ac",
	"flok",
	"--longone",
	"--longone=",
	"mmpf",
	"-d",
	"--longpar",
	"-e",
	"--longopt",
	"--longopt=secty",
	"--longpar=ftkzz",
	"-d=plof",
	"--longpar=",
	"frek",
	"-b=polp",
	"-b=",
	"grmk",
	"-b"
}

local out = {}
local len = #q

for opt,par,err in getopt(q, "c:b=ad?e", {
		"--longone",
		"--longpar=(-lp)",
		"--longopt=?(-lpt)",
		keepargs=true
	}) do
	table.insert(out, { opt=opt, par=par, xer=err })	-- 'xer' so that export will put error at the end
end

dprint(export(out):gsub("},{","},\n{") .. '\n')
dprint(export(out))
assert(export(out) == '{{opt=true,par="prog"},{opt=true,par="glub"},{opt="a",par=true},{opt="b",par="xyz"},{opt="d",par=true},{opt="c",par="val"},{opt=true,par="squnz"},{opt="a",par=true},{opt="c",par="flok"},{opt="--longone",par=true},{opt="?",par="--longone",xer="parameter not allowed"},{opt=true,par="mmpf"},{opt="d",par=true},{opt="?",par="-lp",xer="parameter expected"},{opt="e",par=true},{opt="-lpt",par=true},{opt="-lpt",par="secty"},{opt="-lp",par="ftkzz"},{opt="d",par="plof"},{opt="-lp",par=""},{opt=true,par="frek"},{opt="b",par="polp"},{opt="b",par="grmk"},{opt="?",par="b",xer="parameter expected"}}')
assert(#q == len)


vprint "getopt test ok"
