#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Test suite for tabular module                                           |
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

local tabular = require "geneas.tabular"

if _VERSION:match"Lua 5%.[12]" then
	--
	-- for lua < 5.3 install a 'pairs' function which can iterate over unifications
	--
	_G.pairs = tabular.upairs
end

-- utility function to display the contents of a table in 'flat' form
--
local function showfields(t, title, depth)
	local fields = tabular.fields(t, depth)
	
	sort(fields)
	for _, f in ipairs(fields) do
		local name = f:match"^%[" and title .. f or title .. "." .. f
		
		print(name .. " = " .. tostring(export(tabular.getfield(t, f))))
	end
end
local function dshowfields(...) if _G.debug_level > 0 then showfields(...) end end


-- tabular.mkentry
------------------
dprint"\n...mkentry:"
local a = { 4, x = 5 }
local b = tabular.mkentry(a, 1, 6)
dprint(b)
assert(b==4)
dprint(export(a))
assert(export(a)=="{4,x=5}")

local c = tabular.mkentry(a, 2, 7)
dprint(c)
assert(c==7)
dprint(export(a))
assert(export(a)=="{4,7,x=5}")

local d = tabular.mkentry(a, "x", 8)
dprint(d)
assert(d==5)
dprint(export(a))
assert(export(a)=="{4,7,x=5}")

local e = tabular.mkentry(a, "y", 9)
dprint(e)
assert(e==9)
dprint(export(a))
assert(export(a)=="{4,7,x=5,y=9}")

-- tabular.clone
----------------
dprint"\n...clone:"
local m = {}
setmetatable(a, m)

local f = tabular.clone(a)
dprint(export(f))
assert(export(f)=="{4,7,x=5,y=9}")
assert(getmetatable(f)==nil)

local g = tabular.clone(a, true)
dprint(export(g))
assert(export(g)=="{4,7,x=5,y=9}")
assert(getmetatable(g)==m)

-- tabular.merge
----------------
dprint"\n...merge:"
local h = { [2] = 10, [3] = 11, x = 12, z = 13 }
local k = tabular.merge(g, h)
dprint(export(k))
assert(k==g)
assert(export(k)=="{4,10,11,x=12,y=9,z=13}")

-- tabular.topup
----------------
dprint"\n...topup:"
local p = { 14, 15, 16, 17, 18, y=19, w = 20 }
local q = tabular.topup(k, p)
dprint(export(q))
assert(q==k)
assert(export(q)=="{4,10,11,17,18,w=20,x=12,y=9,z=13}")

-- tabular.remove
-----------------
dprint"\n...remove:"
local r = { 21, [3] = 22, [7] = 23, x = 24, v = 25 }
local s = tabular.remove(q, r)
dprint(export(s))
assert(s==q)
assert(export(s)=="{[2]=10,[4]=17,[5]=18,w=20,y=9,z=13}")

-- tabular.keep
---------------
dprint"\n...keep:"
local t = { 26, 27, 28, 29, w=30, x=31, y=32 }
local u = tabular.keep(s, t)
dprint(export(u))
assert(u==s)
assert(export(u)=="{[2]=10,[4]=17,w=20,y=9}")

-- tabular.mapa
---------------
dprint"\n...mapa:"
local v = tabular.mapa(u, function(n) if n ~= 17 then return n * 2 end end)
dprint(export(v))
assert(export(v)=="{[2]=20,w=40,y=18}")

-- tabular.map
--------------
dprint"\n...map:"
local a = { 1, 2, 3, 4, 5, 6, 7, 8, x = 21 }
local b = tabular.map(a, function(n) if n ~= 6 then return n * 2 end end)
dprint(export(b))
assert(export(b)=="{2,4,6,8,10,[7]=14,[8]=16}")

-- tabular.foldl
----------------
dprint"\n...foldl:"
local c = tabular.foldl(a, function(x, y) return x + y end, 100)
dprint(c)
assert(c==136)

local d = tabular.foldl(a, function(x, y) return 10 * x + y end, 9)
dprint(d)
assert(d==912345678)

-- tabular.foldr
----------------
dprint"\n...foldr:"
local e = tabular.foldr(a, function(x, y) return x + y end, 100)
dprint(e)
assert(e==136)

local f = tabular.foldr(a, function(x, y) return 10 * x + y end, 1)
dprint(f)
assert(f==361)

-- tabular.filter
-----------------
dprint"\n...filter:"
local g = tabular.filter(a, function(x) return x % 3 == 0 end)
dprint(export(g))
assert(export(g)=="{3,6}")

-- tabular.take
---------------
dprint"\n...take:"
local h = tabular.take(a, 3)
dprint(export(h))
assert(export(h)=="{1,2,3}")

local j = tabular.take(a, 30)
dprint(export(j))
assert(export(j)=="{1,2,3,4,5,6,7,8}")

local k = tabular.take(a, 0)
dprint(export(k))
assert(export(k)=="{}")

-- tabular.drop
---------------
dprint"\n...drop:"
local p = tabular.drop(a, 3)
dprint(export(p))
assert(export(p)=="{4,5,6,7,8}")

local q = tabular.drop(a, 30)
dprint(export(q))
assert(export(q)=="{}")

local r = tabular.drop(a, 0)
dprint(export(r))
assert(export(r)=="{1,2,3,4,5,6,7,8}")

-- tabular.append
-----------------
dprint"\n...append:"
local s = { 22, 23, 24 }
local t = tabular.append(r, s)
dprint(export(t))
assert(t==r)
assert(export(t)=="{1,2,3,4,5,6,7,8,22,23,24}")

local u = tabular.append(s, p)
dprint(export(u))
assert(u==s)
assert(export(u)=="{22,23,24,4,5,6,7,8}")

local v = tabular.append(h, a)
dprint(export(v))
assert(v==h)
assert(export(v)=="{1,2,3,1,2,3,4,5,6,7,8}")

local w = tabular.append(a, g)
dprint(export(w))
assert(w==a)
assert(export(w)=="{1,2,3,4,5,6,7,8,3,6,x=21}")

-- tabular.rotate
-----------------
dprint"\n...rotate:"
local x = tabular.rotate(j, 1)
dprint(export(x))
assert(export(x)=="{2,3,4,5,6,7,8,1}")

local y = tabular.rotate(x, -3)
dprint(export(y))
assert(export(y)=="{7,8,1,2,3,4,5,6}")

local z = tabular.rotate(y, 81)
dprint(export(z))
assert(export(z)=="{8,1,2,3,4,5,6,7}")

local zz = tabular.rotate(z, -87)
dprint(export(zz))
assert(export(zz)=="{1,2,3,4,5,6,7,8}")

-- tabular.comprehend
---------------------
dprint"\n...comprehend:"
local c = tabular.comprehend { {1, 2}, {4, 5}, a = {7, 8} }
d2dump(c)
dshowfields(c, "c", 1)
assert(export(c)=="{{1,4,a=7},{1,5,a=7},{2,4,a=7},{2,5,a=7},{1,4,a=8},{1,5,a=8},{2,4,a=8},{2,5,a=8}}")

-- tabular.tcompare
-------------------
dprint"\n...tcompare:"


-- tabular.unify
----------------
dprint"\n...unify:"
local x = {}
local y = { a = 1, b = 2 }
local z = { b = { p = 1, q = 2 }, c = 4 }
local t = tabular.unify { x, y, z, writable = true }
dprint(export(t))
assert(export(t)=="{a=1,b=2,c=4}")

dprint("x:" .. export(x))
dprint("y:" .. export(y))
dprint("z:" .. export(z))

d2dump(t, "cooked")
dshowfields(t, "t", 1)

dprint"\n...set t.a := 5, t.c := nil"
t.a = 5
t.c = nil
assert(export(x)=="{a=5}")
assert(export(y)=="{a=1,b=2}")
assert(export(z)=="{b={p=1,q=2},c=4}")
assert(export(t)=="{a=5,b=2}")

dprint("x:" .. export(x))
dprint("t:" .. export(t))
d2dump(x)
d2dump(t)
dshowfields(x, "x", 1)
dshowfields(y, "y", 1)
dshowfields(z, "z", 1)
dshowfields(t, "t", 1)

-- update y (remove overriding element)
dprint"\n...set y.b := nil"
y.b = nil
assert(export(t)=="{a=5,b={p=1,q=2}}")

dprint("t:" .. export(t))
dshowfields(t, "t", 1)

-- update lower table
dprint"\n...set t.b.r := 9"
t.b.r = 9
assert(export(t)=="{a=5,b={p=1,q=2,r=9}}")

dprint("t:" .. export(t))
dshowfields(t, "t", 1)

-- check caching of sub-unifications
dprint"\n...check unification cache"
repeat
	local tb1 = t.b
	dprint("tb1 = " .. tostring(tb1))
	
	collectgarbage()
	dprint"\n...gc, set t.b.s := { 10 }"
	t.b.s = { 10 }
	dprint("t.b:" .. export(t.b))
	
	local tb2 = t.b
	assert(tb1 == tb2)
	dprint("tb2 = " .. tostring(tb2))
	
	local tb1s = tostring(tb1)
until true
collectgarbage()
local tb3 = t.b
assert(tostring(tb3) ~= tb1s)

dprint("tb3 = " .. tostring(tb3))

-- now put it back...
dprint"\n...set y.b := 7"
y.b = 7
assert(export(t)=="{a=5,b={r=9,s={10}}}")

dprint("t:" .. export(t))
dshowfields(t, "t", 1)

-- now replace t.b with a table
dprint"\n...set t.b := { 1, 2, 3 }"
t.b = { 1, 2, 3 }
assert(export(t)=="{a=5,b={1,2,3}}")

dprint("t:" .. export(t))
dshowfields(t, "t", 1)

-- now remove y.b so that z.b becomes visible; should have no effect
dprint"\n...set y.b := nil"
y.b = nil
assert(export(t)=="{a=5,b={1,2,3}}")

dprint("t:" .. export(t))
dshowfields(t, "t", 1)
d2dump(t, "header=t:")
s = t.b
d2dump(s, "header=s=t.b:")

-- write to t.b
dprint"\n...set t.b[4] := 8"
t.b[4] = 8
assert(export(t)=="{a=5,b={1,2,3,8}}")

dshowfields(t, "t", 1)
dshowfields(x, "x", 1)

dshowfields(t, "t(mask)")


dprint"\n...a = { f = 1 }, b = { g = 2, h = a }, c = unify { a, b }"
local a = { f = 1 }
local b = { g = 2, h = a }
local c = tabular.unify { a, b }
assert(export(c)=="{f=1,g=2,h={f=1}}")

dshowfields(c, "c", 1)

dprint"\n...set a.j := b"
a.j = b
assert(export(c)=="{f=1,g=2,h={f=1,j={g=2,h=<loop>}},j=<loop>}")

dprint(export(c))
dshowfields(c, "c", 2)

local ch = c.h
local cj = c.j

d2dump(c, "header=c:")
d2dump(ch, "header=c.h:")
d2dump(cj, "header=c.j:")


-- tabular.istable
------------------
dprint"\n...istable:"
assert(tabular.istable({}))
assert(not tabular.istable(nil))
assert(not tabular.istable(tabular.NIL))
assert(not tabular.istable(1))

-- tabular.isvalue
------------------
dprint"\n...isvalue:"
assert(not tabular.isvalue({}))
assert(not tabular.isvalue(nil))
assert(tabular.isvalue(tabular.NIL))
assert(tabular.isvalue(1))

-- tabular.putfield
-------------------
dprint"\n...putfield:"
local t = {}
tabular.putfield(t, "a", 1)
tabular.putfield(t, "b.c.d", 2)
tabular.putfield(t, "e[1].f", 3)
tabular.putfield(t, "[1]", 4)
dprint(export(t))
assert(export(t)=="{4,a=1,b={c={d=2}},e={{f=3}}}")

tabular.putfield(t, "a.g", 5)
dprint(export(t))
assert(export(t)=="{4,a={g=5},b={c={d=2}},e={{f=3}}}")

tabular.putfield(t, "b.c", 6)
dprint(export(t))
assert(export(t)=="{4,a={g=5},b={c=6},e={{f=3}}}")

tabular.putfield(t, "e[1].h", 7)
dprint(export(t))
assert(export(t)=="{4,a={g=5},b={c=6},e={{f=3,h=7}}}")

tabular.putfield(t, "e[2][1]", {j={8,k=9}})
dprint(export(t))
assert(export(t)=="{4,a={g=5},b={c=6},e={{f=3,h=7},{{j={8,k=9}}}}}")


-- tabular.getfield
-------------------
dprint"\n...getfield:"
dprint(export(tabular.getfield(t, "a.g")))
assert(export(tabular.getfield(t, "a.g"))=="5")
dprint(export(tabular.getfield(t, "e[1]")))
assert(export(tabular.getfield(t, "e[1]"))=="{f=3,h=7}")

-- tabular.fields
-----------------
dprint"\n...fields:"
local f = tabular.fields(t)
sort(f)
dprint(concat(f,","))
assert(concat(f,",")=="[1],a.g,b.c,e[1].f,e[1].h,e[2][1].j.k,e[2][1].j[1]")

-- tabular.spairs
-----------------
dprint"\n...spairs:"

-- tabular.deepcopy
-------------------
dprint"\n...deepcopy:"

-- tabular.gtable
-----------------
dprint"\n...gtable:"
local s = "asdfc asdfr asdfq asd asdf cgrt"
local a = tabular.gtable(s:gmatch"%a+")
dprint(export(a))
assert(export(a) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')

-- tabular.g2table
-----------------
dprint"\n...g2table:"
local b = tabular.g2table(ipairs(a))
dprint(export(b))
assert(export(b) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')

-- tabular.ginline
-------------------
dprint"\n...ginline:"
local c = { tabular.ginline(s:gmatch"%a+") }
dprint(export(c))
assert(export(c) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')

-- tabular.g2inline
-------------------
dprint"\n...g2inline:"
local d = { tabular.g2inline(ipairs(c)) }
dprint(export(d))
assert(export(d) == '{"asdfc","asdfr","asdfq","asd","asdf","cgrt"}')


vprint "test tabular ok"
