#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     getopt.lua                                                  |
|  Function:   Command line option processing  la gnu getopt               |
|  Created:    20:06:11  30 Oct  2005                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2005-2019 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

if _VERSION:match"Lua 5%.[12]" then
	module("getopt",package.seeall)
end

local remove = table.remove
local findstr = string.find
local substr = string.sub
local strlen = string.len
local match = string.match
local yield = coroutine.yield

--[[
 Usage:
 for option, parameter[, errmsg] in getopt(arg, spec[, longspec]) do
   process option
     option==true => parameter is non-option arg
     option=="?"  => error
 end
 
 spec is string of single-option characters; if ':' follows then mandatory
 parameter follows immediately or in next arg; if '=' follows then mandatory
 parameter follows immediately or in next arg with optional '=' delimiter; if
 '?' follows then optional parameter (indicated by '=' delimiter) follows
 immediately or in next arg.
 longspec is a sequence of long option names, including the preceding '--'
 (it can actually be used to match any argument, even without any '-').
 If followed by '=' or '=?' then parameter follows, optional if '=?'.
 If followed by '(opt)' then opt is returned rather than the long name.
 
 Arguments processed are removed from arg; thus after option processing
 arg contains only non-option arguments.
 If longspec table contains 'returnargs = true' then non-option arguments
 are also returned by the iterator with the option value true.
 If longspec table contains 'keepargs = true' then non-option arguments are
 not removed from arg. Note that keepargs implies returnargs.
 
 If longspec is a boolean then this is taken to be the value of returnargs.
]]

function _G.getopt(args, spec, longspec)
	longspec = longspec == true and { returnargs = true } or longspec or {}
	
	local keepargs = longspec.keepargs
	local returnargs = keepargs or longspec.returnargs
	local tlong
	
	for _,lo in ipairs(longspec) do
		local name, par, rem = match(lo, "^([^=]*)(=?%??)(.-)$")
		local opt = rem == "" and name or substr((match(rem, "%b()") or ""), 2, -2)
		
		if opt == "" then error("getopt: invalid long spec: " .. lo) end
		tlong = tlong or {}
		tlong[name] = { opt = opt, par = ({ ["="] = true, ["=?"] = false })[par] }
	end
	
	return coroutine.wrap(function()
			local i = 1
			local function takearg()
				if keepargs then i = i + 1 else remove(args, i) end
			end
			
			while true do
				local a = args[i]
				
				if not a then break end
				if tlong then
					local p = findstr(a, '=')
					local desc = tlong[p and substr(a, 1, p - 1) or a]
					
					if desc then
						local opt, par = desc.opt, desc.par
						
						takearg()
						if p and par == nil then
							yield('?', opt, "parameter not allowed")
						elseif p then
							yield(opt, substr(a, p + 1))
						elseif not par then
							yield(opt, true)
						else
							yield('?', opt, "parameter expected")
						end
						a = nil
					end
				end
				
				if a and findstr(a, "^%-.") then
					takearg()
									
					local j = 2
					local len = strlen(a)
					
					while j <= len do
						local opt = substr(a, j, j)
						--print("...got option '"..opt.."'")
						
						local function dopar()			-- get parameter
							if j > len then
								a = args[i]					-- all of next arg
								takearg()
							else a = substr(a, j)		-- remainder of current arg
							end
							if a then
								--print("....parameter '"..a.."'")
								yield(opt, a)
							else
								yield('?', opt, "parameter expected")
							end
						end					
						local s = findstr(spec, opt)
						
						j = j + 1
						if not s then
							yield('?', opt, "invalid option")
						elseif findstr(spec, "^:", s + 1) then
							dopar()						-- option with parameter
							break
						elseif findstr(spec, "^=", s + 1) then
							if substr(a, j, j) == "=" then
								j = j + 1				-- consume optional delimiter
							end
							dopar()						-- option with parameter
							break
						elseif findstr(spec, "^%?", s + 1) and substr(a, j, j) == "=" then
							j = j + 1
							dopar()						-- option with optional parameter
							break
						else
							yield(opt, true)			-- option without parameter
						end
					end
				elseif a then
					if returnargs then
						yield(true, a)					-- non-option argument
					end
					i = i + 1
				end
			end
		end)
end
