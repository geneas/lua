#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     test.lua                                                    |
|  Function:   Testbench loader                                            |
|                                                                          |
|  Copyright(c) 2019 Andrew Cannon <ajc@gmx.net>                           |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------
--[[

The purpose of this loader is twofold:
1. an additional searcher function is inserted in first place which causes
all geneas.<name> modules to be loaded from the current directory rather
than any global locations which may have been previously installed. This
ensures that the tests operate on the current versions of all geneas
modules.
2. the test module is called via pcall, so that if it aborts on any error
we can return a non-zero status to the shell which will be detected by
(for example) the make program (when running 'make test')

--]]--

local name		-- name of test module to be run
local map = {}	-- mapping from installed to local names
local options = {}

local debug_level
while true do
	local a = table.remove(arg, 1)
	
	if not a then break
	elseif a == "-z" then debug_level = true
	elseif a:match"^%-m" then
		local mapfile = a:match"-m(.*)"
		if	mapfile then
		   if debug_level then print("mapfile = " .. mapfile) end
			for l in io.lines(mapfile ~= "-" and mapfile) do
				if not l:match"^#" and not l:match"^%s*$" then
					local src, dst = l:match"(.*):(.*)"
					
					if dst then
						--src = src:gsub(".lua$", "")
						--dst = dst:gsub(".lua$", "")
						if debug_level then print("... map " .. src .. " to " .. dst) end
						map[src] = dst
						map[src:gsub(".lua$", "")] = dst:gsub(".lua$", "")
					end
				end
			end
		end
	elseif a:match"^%-o" then
		-- pass option to test module
		-- syntax: -o<test module>:<option>
		-- if <test_module> is empty or it matches the test name then 
		-- the option is added to the test module arguments
		local mod, opt = a:match"..([^:]*):(.*)"
		table.insert(options, { mod = mod, opt = opt })
	elseif a:match"^%-" then
		error "invalid option"
	else
		name = a			-- start of non-option args
		break
	end
end	
	
local mod = name and name:match"(.*)%.lua"
if mod then name = mod end

-- insert new searcher in first position
table.insert(package.loaders or package.searchers, 1, function(modname)
		local file = modname:match"geneas%.(.*)"
		
		if map[file] then file = map[file] end
		
		if debug_level then
			print("package.search: " .. modname .. " -> " .. tostring(file))
		end
		
		if file then
			local sep = package.config:match"^[^\n]+"
			local f, err = loadfile(file:gsub("%.", sep) .. ".lua")
			
			if not f then
				print("trying... " .. file .. sep .. "src" .. sep .. file .. ".so")
				f = package.loadlib(file .. sep .. "src" .. sep .. file .. ".so", "luaopen_geneas_" .. file)
			end
			
			if not f then error(err) end
			return f
		end
	end)

if name then
	local args = { }
	for _, o in ipairs(options) do
		if o.mod == "" or o.mod == name then
			table.insert(args, o.opt)
		end
	end
	
	if map[name] then name = map[name] end
	
	local ok, err = xpcall(function() arg = args; return require("geneas.test." .. name) end, debug.traceback)
	
	if not ok then
		print("\n*** test failed: " .. err .. " ***")
		os.exit(1)
	end
end
