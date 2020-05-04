#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     geneas/init.lua                                             |
|  Function:   Load all geneas utility libraries into global namespace     |
|                                                                          |
|  Copyright(c) 2019 Andrew Cannon <ajc@gmx.net>                           |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local geneas = {}
if _VERSION:match"Lua 5%.[12]" then
	module("geneas",package.seeall)
	geneas = _G.geneas
end

require "geneas.dump"
require "geneas.dprint"
require "geneas.getopt"
require "geneas.export"
require "geneas.class"

geneas.tabular		= require "geneas.tabular"
geneas.split		= require "geneas.split"
geneas.camel		= require "geneas.camel"
geneas.parser		= require "geneas.parser"

geneas.region		= require "geneas.region"
geneas.xml			= require "geneas.xml"
geneas.aatree		= require "geneas.aatree"

geneas.id3			= require "geneas.id3"
geneas.id4			= require "geneas.id4"
geneas.mpi			= require "geneas.mpi"

if not _VERSION:match"Lua 5%.[12]" then
	--
	-- only available for 5.3 and above atm
	--
	geneas.xpm		= require "geneas.xpm"
end

-- move all modules to global namespace
--
geneas.tabular.merge(_G, geneas)

return geneas

