#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Test suite for tabutil module                                           |
|                                                                          |
|  Copyright(c) 2019 Andrew Cannon <ajc@gmx.net>                           |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------
--
-- 17:03:09  24 Jan  2019 - ajc

require "geneas.getopt"
require "geneas.dprint"
require "geneas.export"
require "geneas.dump"

local args = {}
local interactive
for opt, par, err in getopt(arg, "vzid", true) do
	if opt == true then table.insert(args, par)
	elseif opt == "i" then interactive = true
	elseif opt == "v" then verbose = true
	elseif opt == "z" then debug_level = debug_level + 1
	else error "invalid option"
	end
end

local concat = table.concat
local sort = table.sort

local tabutil = require "geneas.tabutil"

-- utility function to display the contents of a table in 'flat' form
--
local function showfields(t, title, depth)
	local fields = tabutil.fields(t, depth)
	
	sort(fields)
	for _, f in ipairs(fields) do
		local name = f:match"^%[" and title .. f or title .. "." .. f
		
		print(name .. " = " .. tostring(export(tabutil.getfield(t, f))))
	end
end
local function dshowfields(...) if _G.debug_level > 0 then showfields(...) end end


-- tabutil.mkentry
------------------
dprint"\n...mkentry:"
local a = { 4, x = 5 }
local b = tabutil.mkentry(a, 1, 6)
dprint(b)
assert(b==4)
dprint(export(a))
assert(export(a)=="{4,x=5}")

local c = tabutil.mkentry(a, 2, 7)
dprint(c)
assert(c==7)
dprint(export(a))
assert(export(a)=="{4,7,x=5}")

local d = tabutil.mkentry(a, "x", 8)
dprint(d)
assert(d==5)
dprint(export(a))
assert(export(a)=="{4,7,x=5}")

local e = tabutil.mkentry(a, "y", 9)
dprint(e)
assert(e==9)
dprint(export(a))
assert(export(a)=="{4,7,x=5,y=9}")

-- tabutil.clone
----------------
dprint"\n...clone:"
local m = {}
setmetatable(a, m)

local f = tabutil.clone(a)
dprint(export(f))
assert(export(f)=="{4,7,x=5,y=9}")
assert(getmetatable(f)==nil)

local g = tabutil.clone(a, true)
dprint(export(g))
assert(export(g)=="{4,7,x=5,y=9}")
assert(getmetatable(g)==m)

-- tabutil.merge
----------------
dprint"\n...merge:"
local h = { [2] = 10, [3] = 11, x = 12, z = 13 }
local k = tabutil.merge(g, h)
dprint(export(k))
assert(k==g)
assert(export(k)=="{4,10,11,x=12,y=9,z=13}")

-- tabutil.topup
----------------
dprint"\n...topup:"
local p = { 14, 15, 16, 17, 18, y=19, w = 20 }
local q = tabutil.topup(k, p)
dprint(export(q))
assert(q==k)
assert(export(q)=="{4,10,11,17,18,w=20,x=12,y=9,z=13}")

-- tabutil.remove
-----------------
dprint"\n...remove:"
local r = { 21, [3] = 22, [7] = 23, x = 24, v = 25 }
local s = tabutil.remove(q, r)
dprint(export(s))
assert(s==q)
assert(export(s)=="{[2]=10,[4]=17,[5]=18,w=20,y=9,z=13}")

-- tabutil.keep
---------------
dprint"\n...keep:"
local t = { 26, 27, 28, 29, w=30, x=31, y=32 }
local u = tabutil.keep(s, t)
dprint(export(u))
assert(u==s)
assert(export(u)=="{[2]=10,[4]=17,w=20,y=9}")

-- tabutil.mapa
---------------
dprint"\n...mapa:"
local v = tabutil.mapa(u, function(n) if n ~= 17 then return n * 2 end end)
dprint(export(v))
assert(export(v)=="{[2]=20,w=40,y=18}")

-- tabutil.map
--------------
dprint"\n...map:"
local a = { 1, 2, 3, 4, 5, 6, 7, 8, x = 21 }
local b = tabutil.map(a, function(n) if n ~= 6 then return n * 2 end end)
dprint(export(b))
assert(export(b)=="{2,4,6,8,10,[7]=14,[8]=16}")

-- tabutil.foldl
----------------
dprint"\n...foldl:"
local c = tabutil.foldl(a, function(x, y) return x + y end, 100)
dprint(c)
assert(c==136)

local d = tabutil.foldl(a, function(x, y) return 10 * x + y end, 9)
dprint(d)
assert(d==912345678)

-- tabutil.foldr
----------------
dprint"\n...foldr:"
local e = tabutil.foldr(a, function(x, y) return x + y end, 100)
dprint(e)
assert(e==136)

local f = tabutil.foldr(a, function(x, y) return 10 * x + y end, 1)
dprint(f)
assert(f==361)

-- tabutil.filter
-----------------
dprint"\n...filter:"
local g = tabutil.filter(a, function(x) return x % 3 == 0 end)
dprint(export(g))
assert(export(g)=="{3,6}")

-- tabutil.take
---------------
dprint"\n...take:"
local h = tabutil.take(a, 3)
dprint(export(h))
assert(export(h)=="{1,2,3}")

local j = tabutil.take(a, 30)
dprint(export(j))
assert(export(j)=="{1,2,3,4,5,6,7,8}")

local k = tabutil.take(a, 0)
dprint(export(k))
assert(export(k)=="{}")

-- tabutil.drop
---------------
dprint"\n...drop:"
local p = tabutil.drop(a, 3)
dprint(export(p))
assert(export(p)=="{4,5,6,7,8}")

local q = tabutil.drop(a, 30)
dprint(export(q))
assert(export(q)=="{}")

local r = tabutil.drop(a, 0)
dprint(export(r))
assert(export(r)=="{1,2,3,4,5,6,7,8}")

-- tabutil.append
-----------------
dprint"\n...append:"
local s = { 22, 23, 24 }
local t = tabutil.append(r, s)
dprint(export(t))
assert(t==r)
assert(export(t)=="{1,2,3,4,5,6,7,8,22,23,24}")

local u = tabutil.append(s, p)
dprint(export(u))
assert(u==s)
assert(export(u)=="{22,23,24,4,5,6,7,8}")

local v = tabutil.append(h, a)
dprint(export(v))
assert(v==h)
assert(export(v)=="{1,2,3,1,2,3,4,5,6,7,8}")

local w = tabutil.append(a, g)
dprint(export(w))
assert(w==a)
assert(export(w)=="{1,2,3,4,5,6,7,8,3,6,x=21}")

-- tabutil.rotate
-----------------
dprint"\n...rotate:"
local x = tabutil.rotate(j, 1)
dprint(export(x))
assert(export(x)=="{2,3,4,5,6,7,8,1}")

local y = tabutil.rotate(x, -3)
dprint(export(y))
assert(export(y)=="{7,8,1,2,3,4,5,6}")

local z = tabutil.rotate(y, 81)
dprint(export(z))
assert(export(z)=="{8,1,2,3,4,5,6,7}")

local zz = tabutil.rotate(z, -87)
dprint(export(zz))
assert(export(zz)=="{1,2,3,4,5,6,7,8}")

-- tabutil.comprehend
---------------------
dprint"\n...comprehend:"
local c = tabutil.comprehend { {1, 2}, {4, 5}, a = {7, 8} }
d2dump(c)
dshowfields(c, "c", 1)
assert(export(c)=="{{1,4,a=7},{1,5,a=7},{2,4,a=7},{2,5,a=7},{1,4,a=8},{1,5,a=8},{2,4,a=8},{2,5,a=8}}")

-- tabutil.tcompare
-------------------
dprint"\n...tcompare:"

-- tabutil.spairs
-----------------
dprint"\n...spairs:"

-- tabutil.gtable
-----------------
dprint"\n...gtable:"
local s = "asdfc asdfr asdfq asd asdf cgrt"
local a = tabutil.gtable(s:gmatch"%a+")
dprint(export(a))
assert(export(a) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')

-- tabutil.g2table
-----------------
dprint"\n...g2table:"
local b = tabutil.g2table(ipairs(a))
dprint(export(b))
assert(export(b) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')

-- tabutil.ginline
-------------------
dprint"\n...ginline:"
local c = { tabutil.ginline(s:gmatch"%a+") }
dprint(export(c))
assert(export(c) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')

-- tabutil.g2inline
-------------------
dprint"\n...g2inline:"
local d = { tabutil.g2inline(ipairs(c)) }
dprint(export(d))
assert(export(d) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')


vprint "test tabutil ok"
