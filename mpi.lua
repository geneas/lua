#! /usr/bin/env lua
--[[-%tabs=3----------------------------------------------------------------
|                                                                          |
|  Module:     mpi.lua                                                     |
|  Function:   Multiprecision Integer Arithmetic in pure lua               |
|                                                                          |
|  Copyright(c) 2019 Andrew Cannon <ajc@gmx.net>                           |
|  Licensed under the terms of the MIT License                             |
|                                                                          |
]]--------------------------------------------------------------------------

local class = require "geneas.class"
local classof = class.classof

local tabutil = require "geneas.tabutil"
local merge = tabutil.merge

local pow = math.pow
local abs = math.abs
local min = math.min
local max = math.max
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt

local insert = table.insert
local remove = table.remove
local concat = table.concat

local format = string.format
local gmatch = string.gmatch
local gsub = string.gsub
local match = string.match
local lower = string.lower
local byte = string.byte
local char = string.char

--[[--------------------------------------------------
|
|	MPI representation:
|
|	{
|		[negative = true,]	-- sign flag
|		[1..] = n,			-- array of digits; [1] is LSD
|	}
|
--]]--------------------------------------------------

-- MPI class object
-------------------
local mpi = {}

-- creator function (fwd ref)
-----------------------------
local _mpi


-- digit format configuration
--
local digit_bits			-- requested format in bits (if > 0) or -(decimal digits) (if < 0)
local digit_unit			-- width unit (2 or 10)
local digit_width			-- digit with in digit_units
local digit_value			-- radix
local digit_squared		-- radix squared (must fit in lua integer)
local digit_max			-- maximum digit value
local digit_mask			-- digit value mask (only if binary format)
local digit_fmt			-- printf format for optimized output if available
local digit_sep			-- digit separator for optimized output

local paranoid = false	-- enable expensive sanity checks
local bitops

local function _setdigit(n)
	local n0, n = digit_bits, tonumber(n)
	
	digit_bits = (not n or n == 0) and 31 or n	-- default digit is 31 bits
	if digit_bits > 0 then
		if digit_bits > 31 then error "mpi.setdigit: digit too large" end
		digit_unit = 2
		digit_width = digit_bits
		digit_fmt = (digit_bits % 4 == 0) and "%0" .. (digit_bits // 4) .. "X" or nil
		digit_value = floor(pow(digit_unit, digit_width))
		digit_mask = digit_value - 1
		digit_sep = ":"
		bitops = true
	else
		if digit_bits < -9 then error "mpi.setdigit: digit too large" end
		digit_unit = 10
		digit_width = -digit_bits
		digit_fmt = "%0" .. digit_width .. "d"
		digit_value = floor(pow(digit_unit, digit_width))
		digit_mask = nil
		digit_sep = ","
		bitops = false
	end
	digit_max = digit_value - 1
	digit_squared = digit_value * digit_value
	return n0
end

local function _setconfig(cfg)
	if cfg.setdigit ~= nil then _setdigit(cfg.setdigit) end
	if cfg.separator ~= nil then digit_sep = cfg.separator or "" end
	if cfg.paranoid ~= nil then paranoid = cfg.paranoid end
	if cfg.divslash ~= nil then mpi.__div = cfg.divslash and mpi.__idiv or nil end
end

local function _getconfig()
	return {
		setdigit = digit_bits,
		unit = digit_unit,
		width = digit_width,
		decs_per_digit = digit_unit == 10 and digit_width or nil,	-- only in decimal mode
		bits_per_digit = digit_unit == 2 and digit_width or nil,	-- only in binary mode
		separator = digit_sep,
		paranoid = paranoid,
		divslash = mpi.__div == mpi.__idiv,
		bitops = bitops,
	}
end

-- setup default digit
_setdigit()
--_setdigit(-3)	-- for testing use base 1000


local function _check(m)
	local len = #m
	
	if m[len] == 0 then error "mpi._check: leading zero (internal)" end
	if m.negative and (m.negative ~= true or len == 0) then error "mpi._check: invalid negative flag (internal)" end
	for _, d in ipairs(m) do
		if d < 0 or d > digit_max then error "mpi._check: invalid digit (internal)" end
	end
end

local function _trim(m)
	-- remove leading zeroes
	local len = #m
	
	while len > 0 and m[len] == 0 do
		remove(m, len)
		len = len - 1
	end
	if not m[1] then m.negative = nil end
	if paranoid then _check(m) end
	return m
end

local function _add(m1, m2, shift)
	local carry = 0
	local index = 1
	local n1, n2 = #m1, #m2
	
	repeat
		local d1 = m1[index + shift]
		local d2 = m2[index]
		local sum = carry + (d1 or 0) + (d2 or 0)
		
		if sum > digit_max then
			sum = sum - digit_value
			carry = 1
		else
			carry = 0
		end
		m1[index + shift] = sum
		index = index + 1
	until (index > n1 or index > n2) and carry == 0
	
	-- copy excess digits from second operand
	local d2 = m2[index]
	while d2 do
		m1[index + shift] = d2
		index = index + 1
		d2 = m2[index]
	end
	
	return _trim(m1)
end

local function _sub(m1, m2, shift)
	local borrow = 0
	local index = 1
	local n2 = #m2
	
	-- NB: caller must ensure that abs(m1 [shifted]) >= abs(m2)
	
	repeat
		local d1 = m1[index + shift]
		
		if not d1 then
			-- should not happen (see NB above)
			print("m1    = "..tostring(m1))
			print("m2    = "..tostring(m2))
			print("index = "..index)
			print("shift = "..shift)
			print("borrow= "..borrow)
			error "mpi._sub: operand error (internal)"
		end
		
		local d2 = m2[index]
		local diff = (d1 or 0) - (d2 or 0) - borrow
		
		if diff < 0 then
			diff = diff + digit_value
			borrow = 1
		else
			borrow = 0
		end
		m1[index + shift] = diff
		index = index + 1
	until index > n2 and borrow == 0
	
	return _trim(m1)
end

local function _cmp(m1, m2)
	local n1, n2 = #m1, #m2
	
	if n1 ~= n2 then return n1 - n2 end
	for i = n1, 1, -1 do
		local d1, d2 = m1[i], m2[i]
		
		if d1 ~= d2 then return d1 - d2 end
	end
	return 0
end

local function _neg(m)
	m.negative = not m.negative or nil
	return m
end

local function _inc(m, shift)
	for i = shift + 1, #m do
		local dig = m[i]
		
		if dig == digit_max then
			m[i] = 0
		else
			m[i] = dig + 1
			return m
		end
	end
	insert(m, 1)
	return m
end

-- scale by whole digits
local function _scale(m, ndig)
	if ndig < 0 then
		for i = 1, -ndig do
			remove(m, 1)
		end
	elseif ndig > 0 then
		for i = 1, ndig do
			insert(m, 1, 0)
		end
	end	
	return m
end

local function _scalen(num, ndig)
	local r = _mpi(num)
	
	for i = 1, ndig do
		insert(r, 1, 0)
	end
	return r
end

-- shift right by <count> units (bits or decimal places)
-- negative count for left shift
local function _shift(m, count)
	if count == 0 then return m end
	
	local digits = count // digit_width	-- NB: floor
	local units = count % digit_width	-- NB: always >= 0
	
	_scale(m, -digits)
	
	if units > 0 then
		-- downshift by this amount
		local sr = 0
		
		if digit_unit == 2 then
			for i = #m, max(1, -digits - 1), -1 do
				sr = (sr << digit_bits) | m[i]
				m[i] = (sr >> units) & digit_mask
			end
		else
			local div = floor(pow(digit_unit, units))
			
			for i = #m, max(1, -digits - 1), -1 do
				sr = (sr % digit_value * digit_value) + m[i]
				m[i] = (sr // div) % digit_value
			end
		end
	end
	return _trim(m)
end

-- return number of free units (bits/decdigits) in digit
local function _freeunits(dig)
	local free = -1
	
	while dig < digit_value do
		dig = dig * digit_unit
		free = free + 1
	end
	return free
end

-- extract digits at position
local function _extract(m, pos, cnt)
	local r = _mpi()
	
	for i = pos + 1, min(#m, pos + cnt) do
		table.insert(r, m[i])
	end
	return r
end

-- multiply by single digit
local function _muln(m, num)
	local carry = 0
	
	if digit_unit == 2 then
		for i, dig in ipairs(m) do
			local prod = dig * num + carry
			
			if prod > digit_max then
				carry = prod >> digit_bits
				prod = prod & digit_mask
			else
				carry = 0
			end
			m[i] = prod
		end
	else
		for i, dig in ipairs(m) do
			local prod = dig * num + carry
			
			if prod > digit_max then
				carry = prod // digit_value
				prod = prod % digit_value
			else
				carry = 0
			end
			m[i] = prod
		end
	end
	if carry > 0 then
		if carry >  digit_max then error "mpi._muln: invalid carry (internal)" end
		insert(m, carry)
	end
	return m
end	

-- multiply by mpi
local function _mul(r, m1, m2)
	if #m1 < #m2 then
		m1, m2 = m2, m1
	end
	for i, dig in ipairs(m2) do
		local carry = 0
		local bufp = i
	
		if digit_unit == 2 then
			for j = 1, #m1 do
				local prod = (r[bufp] or 0) + m1[j] * dig + carry
				
				if prod > digit_max then
					carry = prod >> digit_bits
					prod = prod & digit_mask
				else
					carry = 0
				end
				r[bufp] = prod
				bufp = bufp + 1
			end
		else
			for j = 1, #m1 do
				local prod = (r[bufp] or 0) + m1[j] * dig + carry
				
				if prod > digit_max then
					carry = prod // digit_value
					prod = prod % digit_value
				else
					carry = 0
				end
				r[bufp] = prod
				bufp = bufp + 1
			end
		end
		if carry > 0 then
			if carry > digit_max then error "mpi._mul: invalid carry (internal)" end
			
			carry = carry + (r[bufp] or 0)
			
			if carry <= digit_max then
				r[bufp] = carry
			else
				-- carry
				--
				r[bufp] = carry - digit_value
				_inc(r, bufp)
			end
		end
	end
	return r
end

-- divide by single digit, return remainder
local function _divn(q, m, num)
	local rem = 0
	
	for i = #m, 1, -1 do
		local acc = rem * digit_value + m[i]
		
		q[i] = acc // num
		rem = acc % num
	end
		
	_trim(q)
	return rem
end

-- divide by mpi
local function _divmod(a, b)
	--
	-- long division
	-- this implementation using Byte Division method [Rice & Hughey 1998]
	--
	local len = #b
	
	-- shift a & b left to achieve maximum accuracy for single-digit r0
	-- r0 = 1/b (shifted) [nb: r0 must be <= the true reciprocal]
	--
	local P = _mpi(a)
	local shift = _freeunits(b[len]) + 1
	if shift == digit_width then
		shift = 0
	else
		b = _mpi(b)
		_shift(b, -shift)
		_shift(P, -shift)
		len = #b
	end
		
	local r0 = digit_squared // (b[len] * digit_value + b[len - 1] + 1)
	local quo = _scalen(0, #P - len + 1)
	repeat
		local ppos = #P
		local qpos = ppos - len + 1
		local p = P[ppos]	
		local q0 = p * r0
		
		if q0 > digit_max then
			q = q0 // digit_value	-- use high digit
		elseif qpos > 1 then
			q = q0
			qpos = qpos - 1			-- use low digit
		else
			q = 1							-- q must be > 0
		end
		
		-- update partial remainder
		_sub(P, _muln(_mpi(b), q), qpos - 1)
		
		-- accumulate quotient
		--
		local qn = quo[qpos] + q
		
		if qn <= digit_max then
			quo[qpos] = qn
		else
			-- carry
			--
			quo[qpos] = qn - digit_value
			_inc(quo, qpos)
		end

		local diff = _cmp(P, b)
	until diff < 0
	
	if shift > 0 then
		--
		-- shift remainder back to correct position
		--
		_shift(P, shift)
	end
	
	return _trim(quo), P
end

-- conversion functions

local function _loadn(r, n)
	if n < 0 then
		r.negative = true
		n = -n
	end
	if n > 0 then
		repeat
			insert(r, n % digit_value)
			n = n // digit_value
		until n < 1
	end
	return r
end

local function _loadstr(r, s, radix)
	local sep = gsub(digit_sep, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
	local sign, base, num = match(s, "^([+-]?)(0?[xX]?)([%x" .. sep .. "]+)$")
	
	if not sign then error "mpi: failed to parse" end
	if not radix then
		if match(base, "0[xX]") then radix = 16
		elseif base == "0" then radix = 8
		else radix = 10
		end
	end
	if radix < 2 or radix > 36 then error "mpi: invalid radix" end
	for c in gmatch(num, "%x") do
		local digit =	match(c, "%d") and byte(c) - 48
					or	match(c, "%u") and byte(c) - 55
					or	match(c, "%l") and byte(c) - 87
					or 	radix
		
		if digit >= radix then error "mpi: invalid digit" end
		
		_add(_muln(r, radix), { [1] = digit }, 0)
	end
	r.negative = #r > 0 and sign == "-" or nil
	return r
end

local function _tostring(m, radix, lc, sep)
	local t = {}
	
	if paranoid then _check(m) end
	
	radix = type(radix) == "number" and radix > 2 and radix or 10
	
	if digit_fmt and radix == (digit_bits > 0 and 16 or 10) then
	
		-- optimisation for decimal/hex digits
		-- (doesn't depend on divide function)
		
		local fmt = lc and lower(digit_fmt) or digit_fmt
		
		for _, dig in ipairs(m) do
			insert(t, 1, format(fmt, dig))
		end
		if #t == 0 then
			t[1] = "0"
		else
			t[1] = match(t[1], "^0*(.*)")	-- remove leading zeroes
		end
		
		local s = concat(t, sep or digit_sep)
		
		return m.negative and "-" .. s or s
	else
		local tmp = _mpi(m)
		local alpha = lc and 87 or 55
		
		while #tmp > 0 do
			local quo = _mpi()
			local rem = _divn(quo, tmp, radix)
			
			tmp = quo
			insert(t, 1, char((rem > 9 and alpha or 48) + rem))
		end
		if #t == 0 then t[1] = "0" end
		if m.negative then insert(t, 1, "-") end
		return concat(t, "")
	end
end

local function _tonumber(m)
	local len = #m
	
	if len == 0 then return 0 end
	
	local acc = m[len]
	
	for i = len - 1, 1, -1 do
		acc = acc * digit_value + m[i]
	end
	return m.negative and -acc or acc
end

local function _concat(m1, m2)
	m1 = (classof(m1) == mpi and _tostring or tostring)(m1)
	m2 = (classof(m2) == mpi and _tostring or tostring)(m2)
	
	return m1 .. m2
end

-------------------------------------

local function read(s, radix)
	return _loadstr(_mpi(), s, radix)
end

local function add(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	if m1.negative == m2.negative then
		return _add(_mpi(m1), m2, 0)
	else
		local sgn = _cmp(m1, m2)	-- compare magnitudes
		
		if sgn > 0 then
			return _sub(_mpi(m1), m2, 0)
		elseif sgn < 0 then
			return _sub(_mpi(m2), m1, 0)
		end
		return _mpi()				-- result is 0
	end
end

local function sub(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	if m1.negative ~= m2.negative then
		return _add(_mpi(m1), m2, 0)
	else
		local sgn = _cmp(m1, m2)	-- compare magnitudes
		
		if sgn > 0 then
			return _sub(_mpi(m1), m2, 0)
		elseif sgn < 0 then
			return _neg(_sub(_mpi(m2), m1, 0))
		end
		return _mpi()				-- result is 0
	end
end

local function mul(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	local negative = m1.negative
	if m2.negative then negative = not negative or nil end
	
	return _mul(_mpi(negative), m1, m2)
end

local function divmod(m1, m2, tozero)
	local m2int
	
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then
		m2int = true
		m2 = _mpi(m2)
	end
	if #m2 == 0 then error "mpi: divide by zero" end
	
	local negative = m2.negative
	if m1.negative then negative = not negative or nil end
	
	local quo
	local rem	
	
	if #m2 < 2 then
		
		-- divide by single-digit number
		
		quo = _mpi(negative)
		rem = _divn(quo, m1, m2[1])
		
		if rem ~= 0 then
			if tozero then
				if m1.negative then
					rem = -rem
				end
			else
				if negative then
					_inc(quo, 0)
					rem = m2[1] - rem
				end
				if m2.negative then
					rem = -rem
				end
			end
		end
		if not m2int then
			rem = _mpi(rem)
		end
	else
		-- long division
		
		local diff = _cmp(m1, m2)
		
		if diff == 0 then
			quo = _mpi(1)
			rem = _mpi()
		elseif diff < 0 then
			quo = _mpi()
			rem = _mpi(m1)	-- sign will be overwritten
		elseif diff > 0 then
			quo, rem = _divmod(m1, m2)
		end
		
		quo.negative = negative
		if #rem > 0 then
			if tozero then
				rem.negative = m1.negative
			else
				if negative then
					_inc(quo, 0)
					rem = (_sub(_mpi(m2), rem, 0))
				end
				rem.negative = m2.negative
			end
		end
		if m2int then
			rem = _tonumber(rem)
		end
	end
	
	if paranoid then
		-- check
		local check = quo * m2 + rem
		
		if check ~= m1 then
			print("m1    = "..tostring(m1))
			print("m2    = "..tostring(m2))
			print("quo   = "..tostring(quo))
			print("rem   = "..tostring(rem))
			error "mpi: divmod check failed (internal)"
		end
	end
	
	return quo, rem
end

local function idiv(m1, m2)
	return (divmod(m1, m2))
end

local function imod(m1, m2)
	return select(2, divmod(m1, m2))
end

local function pow(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	
	local expon = type(m2) == "number" and m2 or _tonumber(m2)
	
	if expon <= 0 then
		if expon == 0 then return _mpi(1)
		else error "mpi.pow: negative exponent"
		end
	end
	
	local odd = (expon & 1) == 1
	local negative = odd and m1.negative
	local acc = m1
	local r = odd and acc
	
	while expon > 1 do
		acc = _mul(_mpi(), acc, acc)
		expon = expon >> 1
		if (expon & 1) == 1 then
			r = r and _mul(_mpi(), r, acc) or acc
		end
	end
	
	r.negative = negative
	return r
end

local function uminus(m)
	local r = _mpi(m)
	
	if #m > 0 then r.negative = not r.negative or nil end
	return r
end

local function abs(m)
	local r = _mpi(m)
	
	r.negative = nil
	return r
end

-- bit operations

local function band(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	local r = _mpi(m1.negative and m2.negative)
	
	for i = 1, min(#m1, #m2) do
		r[i] = m1[i] & m2[i]
	end
	return _trim(r)
end

local function bor(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	local r = _mpi(m1.negative or m2.negative)
	
	for i = 1, max(#m1, #m2) do
		r[i] = (m1[i] or 0) | (m2[i] or 0)
	end
	return r
end

local function bxor(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	local r = _mpi(m1.negative)
	
	if m2.negative then r.negative = not r.negative or nil end
	for i = 1, max(#m1, #m2) do
		r[i] = (m1[i] or 0) ~ (m2[i] or 0)
	end
	return _trim(r)
end

-- note:
-- there is no bnot() operation as it would have to return an infinite
--	number of bits! use bxor with inversion mask of appropriate length.

-- shifts

local function shr(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	
	return _shift(_mpi(m1), type(m2) == "number" and m2 or _tonumber(m2))
end

local function shl(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	
	return _shift(_mpi(m1), -(type(m2) == "number" and m2 or _tonumber(m2)))
end

-- comparisons

local function eq(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	return not m1.negative == not m2.negative and _cmp(m1, m2) == 0
end

local function lt(m1, m2)
	if type(m1) == "number" then m1 = _mpi(m1) end
	if type(m2) == "number" then m2 = _mpi(m2) end
	
	if m1.negative then return not m2.negative or _cmp(m1, m2) > 0
	else return not m2.negative and _cmp(m1, m2) < 0
	end
end

local function gt(m1, m2) return lt(m2, m1) end
local function ge(m1, m2) return not lt(m1, m2) end
local function le(m1, m2) return not gt(m1, m2) end
local function ne(m1, m2) return not eq(m1, m2) end

-- queries
--

local function sigplaces(m)
	--
	-- return the number of significant units (bits/decimal digits)
	-- ...this can be interpreted as 1 + the floor of the logarithm:
	--    ie log2 (binary mode) or log10 (decimal mode)
	--
	local len = #m
	
	return len == 0 and 0 or len * digit_width - _freeunits(m[len])
end

local function extract(m, pos)
	--
	-- extract data at specified position as lua integer
	-- ...default is to return maximum amount (up to two digits) of MS data
	-- ...pos is start (LS) unit position from LSD, or if < 0 then from MSD
	--
	pos = max(0, (pos and pos >= 0) and pos or sigplaces(m) + (pos or digit_width * -2))
	
	local data = _shift(_extract(m, pos // digit_width, 3), pos % digit_width)
	
	return (data[1] or 0) + (data[2] or 0) * digit_value, pos
end


-- high level functions
--

-- calculate floor of square root using babylonian (heron's) method [wikipedia]
function isqrt(m)
	if m.negative then error "mpi.isqrt: illegal operand" end
	if #m == 0 then return _mpi() end
	
	local u = sigplaces(m)
	local w = digit_width * 2 - (u & 1)	-- ensure that pos will be even
	local msu, pos = extract(m, -w)
	local x, x0 = _mpi(ceil(sqrt(msu + 1))) << (pos // 2)
	
	repeat
		x0, x = x, (x + m // x) // 2
	until x >= x0
	
	if paranoid then
		if x0 * x0 > m then error "mpi.sqrt: result too large (internal)" end
		if (x0 + 1) ^ 2 <= m then error "mpi.sqrt: result too small (internal)" end
	end
	return x0
end
	
-- calculate GCD
function gcd(m1, m2)
	if m1 < m2 then
		m1, m2 = m2, m1
	end
	while m2[1] do	-- while m2 ~= 0
		m1, m2 = m2, m1 % m2
	end 
	return m1
end

-- NB: this is called by the constructor function to initialize the object data
--
local function initialize(m, init)
	if not init then -- leave empty
	elseif init == true then m.negative = true
	elseif classof(init) == mpi then merge(m, init)
	elseif type(init) == "number" then
		local n = init < 0 and ceil(init) or floor(init)
		
		if n == 0 then -- leave empty
		elseif n > 0 and n <= digit_max then m[1] = n
		elseif n < 0 and n >= -digit_max then m[1] = -n; m.negative = true
		else _loadn(m, n)
		end
	elseif type(init) == "string" then
		_loadstr(m, init)
	else
		error "mpi: invalid initializer"
	end
	return m
end


-- object methods
--
local methods = {
	tonumber		= _tonumber,
	tostring		= _tostring,

	length		= function(m) return #m end,
	sigplaces	= sigplaces,
	extract		= extract,
}

-- metatable operations
--
mpi.__add		= add
mpi.__sub		= sub
mpi.__mul		= mul
mpi.__div		= function() error "mpi: illegal fractional division" end
mpi.__idiv		= idiv
mpi.__mod		= imod
mpi.__pow		= pow

mpi.__unm		= uminus

mpi.__eq			= eq
mpi.__lt			= lt
mpi.__le			= le

mpi.__band		= band
mpi.__bor		= bor
mpi.__bxor		= bxor
mpi.__bnot		= function() error "mpi: illegal bitwise inversion" end

mpi.__shl		= shl
mpi.__shr		= shr

mpi.__concat	= _concat
mpi.__tostring	= _tostring

mpi.__index		= methods

-- constructor/initializer
--
mpi.init			= initialize

-- class methods
--
mpi.read			= read
mpi.add			= add
mpi.sub			= sub
mpi.mul			= mul
mpi.pow			= pow
mpi.cmp			= cmp
mpi.neg			= uminus
mpi.div			= idiv
mpi.mod			= imod
mpi.divmod		= divmod
mpi.divrem		= function(a, b) return divmod(a, b, true) end
mpi.eq			= eq
mpi.lt			= lt
mpi.le			= le
mpi.ne			= ne
mpi.gt			= gt
mpi.ge			= ge
mpi.band			= band
mpi.bor			= bor
mpi.bxor			= bxor
mpi.shl			= shl
mpi.shr			= shr
mpi.abs			= abs
mpi.isqrt		= isqrt
mpi.gcd			= gcd
	
-- module configuration
mpi.setdigit	= _setdigit
mpi.setconfig	= _setconfig
mpi.getconfig	= _getconfig


-- include all object methods as class methods
merge(mpi, methods)

-- create class
--
class(mpi)

-- setup forward reference to creator function for internal use
--
_mpi = mpi

-- return class as module
--
return mpi
