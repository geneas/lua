#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Install geneas utility modules                                          |
|                                                                          |
|  Copyright(c) 2019 Andrew Cannon <ajc@gmx.net>                           |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------
--[[

usage:

install {<files to install>}

]]--

require "getopt"
require "dprint"

local args = {}
local dry_run
local namefile
local subdir
for opt, par, err in getopt(arg, "vznf:d:", { "--subdir=(d)", "--files=(f)", "--dry-run(n)", "--verbose(v)", "--debug(z)", returnargs = true }) do
	if opt == true then table.insert(args, par)
	elseif opt == "d" then subdir = par
	elseif opt == "f" then namefile = par
	elseif opt == "n" then dry_run = true
	elseif opt == "v" then verbose = true
	elseif opt == "z" then debug_level = debug_level + 1
	else error "invalid option"
	end
end

local lua51 = _VERSION:match"Lua 5%.[12]"
local paths = package.path


-- determine possible global installation paths
--
local dirs = {}
for path in paths:gmatch"([^;]+)[/\\]%?%.lua" do
	if path:match"^/" or path:match"^%a:\\" then
		table.insert(dirs, path)
		d3printf("add path '%s'", path)
	end
end

for _, dir in ipairs(dirs) do
	--
	-- attempt install to this path
	--
	local sep = dir:match"[/\\]"
	
	local function dofiles(files)
		local sub = ""
		
		if subdir then
			sub = sep .. subdir
			
			local dirpath = dir .. sub
			
			d3printf("...make dir '%s'", dirpath)
			if not dry_run then
				local cmd = "mkdir " .. dirpath
				
				if io.popen then	-- unix-like
					cmd = cmd .. " 2>/dev/null"
				end
				os.execute(cmd)
			end
		end
		for i, file in ipairs(files) do
			local dst, src = file:match"(.*):(.*)"
			
			if dst then file = src
			else dst = file
			end
				
			local path = dir .. sub .. sep .. dst
			
			d3printf("...%d: copy '%s' to '%s'", i, file, path)
			if not dry_run then
				local function compare()
					local ofd = io.open(path, "r")
					
					if not ofd then return false end
					
					local ifd = io.open(file, "r")
					repeat
						local block1 = ifd:read(4096)
						local block2 = ofd:read(4096)
						
						if block1 ~= block2 then
							return false
						end
					until not block1
					ofd:close()
					ifd:close()
					return true
				end
				
				-- compare
				if compare() then
					d2printf("no change for '%s'", path)
				else
					-- attempt copy
					local ofd = io.open(path, "w")
				
					if not ofd then
						if i == 1 then return end
						error("failed to create '" .. path .. "'")
					end
					
					local ifd = io.open(file, "r")
					repeat
						local block = ifd:read(4096)
						
						if block then
							ofd:write(block)
						end
					until not block
					ifd:close()
					ofd:close()
					
					-- verify
					if not compare() then
						error("verify failed for '" .. path .. "'")
					end
					if i == 1 then
						vprintf("installation path: '%s'", dir)
					end
					vprintf("...installed '%s'", path)
				end
			end
		end
		return not dry_run
	end
	
	dprintf("...trying directory '%s'", dir)
	
	local files
	if namefile then
		files = {}
		for l in io.lines(namefile ~= "-" and namefile) do
			if not l:match"^#" and not l:match"^%s*$" then
				table.insert(files, l:match("^%s*(.-)%s*$"))
			end
		end
	else
		files = args
	end
	
	if dofiles(files) then
		vprintf("installation complete")
		return
	end
end
	
vprintf("installation failed (sudo?)")
