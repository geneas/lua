#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     class.lua                                                   |
|  Function:   Class to create classes                                     |
|  Created:    19:03:26  11 Dec  2018                                      |
|  Author:     Andrew Cannon <ajc@gmx.net>                                 |
|                                                                          |
|  Copyright(c) 2018-2022 Andrew Cannon                                    |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local class = {}
if _VERSION:match"Lua 5%.[12]" then
	module("class", package.seeall)
	class = _G.class
end

local type = _G.type
local pairs = _G.pairs
local tostring = _G.tostring
local getmetatable = _G.getmetatable
local setmetatable = _G.setmetatable
local assert = _G.assert or function(p) if not p then error("assertion failed", 2) end end

-- class class
--------------

--[[------------------------------------------------------------------------

	              ---------------
	object(s):    |             |
	         /====|[meta]       |
	         H    ---------------
	         H 
	         H 
	         \==> ---------------
	class:        | name=<...>  |
	(operations   | init:fn     |
	 & statics)   |             |    class (singleton)
	              |       [meta]|==> ------------
	         /----|__index      |    |    __call|--> newobject()
	         \..> ---------------    |          |
	         |                       |          |    classmeta
	         |                       |    [meta]|==> -----------
	         \--> ---------------    ------------    |         |
	functions:    |             |                    |   __call|--> newclass()
	(methods)     |             |                    -----------
	(optional)    |             |
	              ---------------


]]--------------------------------------------------------------------------

local function classof(obj)
	local mt = type(obj) == "table" and getmetatable(obj)

	return mt and (mt == class or getmetatable(mt) == class) and mt or nil
end

local function iskindof(obj, cls)
	if cls then
		local c = classof(obj)
	
		return c and c == cls or iskindof(obj, c.super)
	end
	return false
end

local function objtype(obj)
	local c = classof(obj)

	return c and (c.name and ("class " .. c.name)
	                     or tostring(c):gsub("table", "class"))
	         or type(obj)
end

local function newclass(c, newcl)
	assert(c == class)
	
	if type(newcl) == "string" then
		newcl = { name = newcl }
	end
	setmetatable(newcl, class)
	newcl.__metatable = newcl					-- lock metatable
	newcl.__index = newcl.__index or newcl	-- default to methods in class object
	return newcl
end

local function newobject(cls, p, ...)
	assert(getmetatable(cls) == class)
	
	local init = cls.init
	
	if not init then
		return setmetatable(p or {}, cls)
	else
		local obj = setmetatable(objtype(p) == "table" and p or {}, cls)
		local ret = init(obj, p, ...)
		
		-- the init function may return:
		-- = the same object or nil, or
		-- = a new table, in which case the metatable needs to
		--   be set on the new table, or
		-- = an object, in which case the data must be copied,
		--   because we can't change an object metatable
		-- = an error object (string)
		--
		if ret == obj then
			return obj
		elseif type(ret) == "table" then
			if not classof(ret) then
				return setmetatable(ret, cls)
			end
			for k, v in pairs(ret) do obj[k] = v end
		elseif ret then
			return nil, ret	-- error object
		end
		return obj
	end
end

-- inheritance by template:
-- copy in methods of superclass which are not already defined.
--
-- caveat: if cls & super do not make the same distinction between
-- class & object methods then the child class will inherit all of
-- the super class methods as both class & object methods.
--
local function extends(cls, super)
	-- copy class methods
	for k, v in pairs(super) do
		if not cls[k] then cls[k] = v end
	end
	
	-- copy object methods
	if not rawequal(cls.__index, cls) then
		for k, v in pairs(super.__index) do
			if not cls.__index[k] then cls.__index[k] = v end
		end
	elseif not rawequal(super.__index, super) then
		for k, v in pairs(super.__index) do
			if not cls[k] then cls[k] = v end
		end
	end
	
	cls.super = super
	return cls
end


local classmeta = {
	__call = newclass,						-- class() -> new class
}
classmeta.__metatable = classmeta		-- lock metatable


class.classof = classof
class.iskindof = iskindof
class.type = objtype

class.name = "class"
class.__call = newobject					-- <class>() -> new object
class.__metatable = class					-- lock metatable

return setmetatable(class, classmeta)
