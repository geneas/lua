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
require "geneas.dump"

local tabular = require "geneas.tabular"

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

local loadstr = _VERSION:match"Lua 5.1" and loadstring or load

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


-- tabular.unify
----------------
dprint"\n...unify:"
local x = {}
local y = { a = 1, b = 2 }
local z = { b = { p = 1, q = 2 }, c = 4 }
local t = tabular.unify { x, y, z, writable = true }
dprint"\n...created unification:"
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

-- tabular.deepcopy
-------------------
dprint"\n...deepcopy:"
local a = { 1 }
local b = { { 2, 3 }, a }
local c = { a = a, b = b }
d2dump(c)

local cs = ""
dump(c, {seq=true, flat=true, writer=function(s) cs = cs .. s end})

local map = {}
local x1 = tabular.deepcopy(c, map)
d2dump(x1)
assert(x1.b[2] ~= c.b[2])

local xs = ""
dump(x1, {seq=true, flat=true, writer=function(s) xs = xs .. s end})
assert(xs == cs)

local x2 = tabular.deepcopy(c, nil, { b })			-- copy b by reference
d2dump(x2)
assert(x2.b == c.b)

local x3 = tabular.deepcopy(c, map)						-- re-use previous mapping
d2dump(x3)
assert(x3.a == x1.a)
assert(x3.b == x1.b)

local xs = ""
dump(x3, {seq=true, flat=true, writer=function(s) xs = xs .. s end})
assert(xs == cs)

-- tabular.export
-----------------
dprint"\nexport:"
x1 = "abc"
x2 = 4
-- tree:
x3 = { 1, "two", three = { "sub", [4] = {{77}, [{8}] = 9}}}
-- DAG:
x4 = { 9, 10, x3, { 11, { x3 }}}
-- with loops:
x51 = { 21, { a = x3 }}
x52 = { 22, { b = x4, c = x51 }}
x5 = { 23, { x52, {{ x51 }}}}
x51[3] = x52

-- complex with metatable and key references
xa = { "a", { "a2" }}
xb = { "b", { "b2" }}
xc = { "c" }
xd = { "d", { "d1", d22 = xb, d23 = xc }}
xe = { "e", xd, e3 = { "e3", [xc] = 7, e33 = { "e33", [xa] = { "e332", xb }}}}
xf = { "f", nil, 77, { "f4", xa }}
xg = { "g", {"g2", setmetatable({ "g22", xf }, xa)}}
x6 = { "x", { "x2", { "x22", xg, setmetatable({ "x223", xe }, xd) }, { "x224", xe, { "x2243", xd, "tab\tline\nbreak", xb }}}}

xf["end"] = xg
xc.c2 = xd
xe[xb] = x6
setmetatable(xb, xe)
setmetatable(xc, xa)

local function test_export(x)
	local s = tabular.export(x, "pretty")
	--print(s)
	local y = loadstr("return " .. s)()
	local v = tabular.export(y, "pretty")
	if v ~= s then
		print("export failed: " .. v)
		d3dump(y)
	end
end

test_export(x1)
test_export(x2)
test_export(x3)
test_export(x4)
test_export(x5)
test_export(x6)

vprint "test tabular ok"
