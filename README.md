# geneas/lua

__Lua utility library__


### dprint.lua

**require "geneas.dprint"**

Installs a family of global functions d[n]print which conditionally generate output (like print) depending
on the value of the global numerical variable 'debug_level' (which is initialized to 0). Thus for example d2print(...) only produces output
if the value of debug_level is 2 or greater. The function dprint generates output if debug_level is non-zero.

In addition, a global function printf is installed which prints the output of string.format. A
similar family of d[n]printf functions is also installed which check the value of debug_level.
Finally the global functions vprint and vprintf are installed which only generate output if the
global boolean variable 'verbose' tests true.

An optional header can be defined by setting the global string variable debug_header. This header
can include escape sequences as defined for os.date(), or %? for the current value of debug_level
or %@ for the minimum level of the dprint call (ie 2 for d2print etc).

Output is generated via io.stdout:write(), unless a global function debug_writer has been
defined, in which case this function is called with the formatted output instead. Each call to any
of the print functions results in a single call to the output function.

*setDebugLevel(n)*

Set current debug level

*incDebugLevel()*

Increment current debug level

*decDebugLevel()*

Decrement current debug level

*getDebugLevel()*

Returns current debug level (same as _G.debug_level)

*setVerbose(t)*

Set verbose flag to t (default true)

*getVerbose()*

Returns current verbose setting (true of false) (same as _G.verbose)

*d**n**print(...)*

Print args (tab separated) and newline if current debug level >= n

*d*n*printf(fmt, ...)*

Print args (formatted) and newline if current debug level >= n

*vprint(...)*

Print args (tab separated) and newline if verbose setting is true

*vprintf(fmt, ...)*

Print args (formatted) and newline if verbose setting is true


### dump.lua

**require "geneas.dump"**

Installs a global function 'dump' which produces a nicely formatted dump of a lua object.

*dump(data, flags)*

_data_ may be any lua data item including nil. _flags_ may be specified to control various properties of the output, in particular how tables are displayed. The following flags are defined:

    maxlev=<num>   specify maximum depth of tables to be shown
    indent=<ind>   specify indent string or number of spaces per indent level
    expand         expand duplicated table entries (otherwise each table is only shown once)
    cooked         access table entries using pairs() rather than next() and rawget()
    nometa         do not show metatable
    writer=<func>  specify alternative writer function; default is to use io.stdout:write()
    header=<str>   specify a header to be printed at the start of the first line of the dump
    align          indent all lines of the dump to align them with the header
    sort[=<func>]  sort table entries alphanumerically, or using specified function
    hexkey         display integer keys in hex
    hexval         display integer values in hex
    flat           single line format (no pretty-printing)

Flags may be specified as a table or a string. If a table then each flag is a key with the associated value or _true_ for boolean flags. If a string then flags are comma separated groups of the form 'flag=value' or simply 'flag' for boolean flags.

Further notes regarding flags:
* If a header is specified with flags in string form then it must be the last flag and its value is the remainder of the string.
* If a writer function is specified it may be a function or a string value; in the latter case it is assumed to be the name of a function in the global namespace. Note that this is the only way to specify a writer when the flags are in string form.
* A sort function can only be specified if flags is in table form, and must then be a function value.
* If flags is in string form then indent can only be specified as a number (of spaces).
* The flags parameter may be a number in which case it is interpreted as the value of maxlev.
* The flags parameter have the value _true_ in which case it is interpreted as 'cooked'.


### getopt.lua

**require "geneas.getopt"**

Installs a global function 'getopt' which processes commandline options similarly to gnu getopt.

*getopt(arg, spec[, longspec])*

The getopt function returns an iterator function which will return all options and (optionally) non-option arguments found in the command-line argument array _arg_.

Each time the iterator function is called it returns up to three values: an option name, a parameter value (or nil) and an error message (or nil).

Short options are specified in the string _spec_; each option character may be followed by a modifier character:

    ':'  a parameter is expected either immediately or in the next arg entry
    '='  as above; if a '=' character follows the option letter then it is ignored
    '?'  if a '=' character follows the option letter then a parameter follows as above

Long option names may be specified in the array _longspec_. Each entry consists of the full name of the long option (including initial '--'). If the name is followed by '=' then the long option must be followed immediately by an '=' character and a parameter value (which may be empty). If the name is followed by '=?' then the '=' and parameter value are optional. Finally, the name and parameter spec may be followed by an alias enclosed in parentheses. If specified then the alias will be returned instead of the long option name; this can be the name of the corresponding short option.

By default, getopt removes arguments containing options and option parameters from the _arg_ array, and does not return any indication of non-option arguments to the caller.

If the _longspec_ table contains an entry 'returnargs=true' then non-option arguments are also returned by the iterator function with the first return value (option name) set to nil and the second return value containing the value of the argument.

If the _longspec_ table contains an entry 'keepargs=true' then arguments containing options and option parameters are not removed from the _arg_ array. In this case non-option arguments are also returned by the iterator function as for 'returnargs=true' above.

Example:
    require "geneas.dprint"
    require "geneas.getopt"
    local args = {}
    for opt, par, err in getopt(arg, "o:vz", { "--output=(o)", "--verbose(v)", "--debug(z)", returnargs = true }) do
        if opt == true then table.insert(args, par)
        elseif opt == "o" then outfile = par
        elseif opt == "v" then setVerbose(true)
        elseif opt == "z" then incDebugLevel()
        else error(err)
        end
    end



### export.lua

**require "geneas.export"**

Installs a global function 'export' which exports hierarchical string & numerical data in tables
in a format which can be read back in to reproduce the data structure. Only DAGs containing keys
and values which can be converted to strings are supported.

Example:
    require "geneas.export"
    local t = { 1, 2, a = 3, { 4, b = 5 }, c = { 6 } }
    local s = export(t)
    local t2 = load("return " .. s)()
    -- now t2 == t


### camel.lua

**local camel = require "geneas.camel"**

Provides functions to convert between camel case and underscore-separated names.

*camel.to(s, capital)*

Convert _s_ to camel-case. If *capital* is true then the initial letter of the result is capitalised, otherwise it is in lower case.

*camel.from(s)*

Convert _s_ from camel-case to lower case underscore-separated format.



### tabutil.lua

**local tabutil = require "geneas.tabutil"**

This module contains a number of utility functions for operating on tables:


*tabutil.mkentry(tab, key, def)*

Returns tab[key] if it exists, otherwise initializes tab[key] = def and returns it.


*tabutil.clone(t[, withmeta])*

Creates a shallow (single-level) copy of a table including (optionally) the metatable.


*tabutil.merge(t1, t2)*

Copies all entries from t2 to t1 (overwriting existing entries) and returns t1.


*tabutil.topup(t1, t2)*

Copies all entries from t2 that are not already in t1 and returns t1.


*tabutil.remove(t1, t2)*

Removes all keys from t1 that are present in t2, and returns t1.


*tabutil.keep(t1, t2)*

Removes all keys from t1 that are not present in t2, and returns t1.


*tabutil.mapa(t, f)*

Constructs a new table with t[k]=f(v) for all k,v in pairs(t).


**The following functions operate on arrays and ignore non-array keys:**


*tabutil.map(t, f)*

Constructs a new array containing t[i]=f(v) for all i,v in ipairs(t).


*tabutil.foldl(t, f, r)*

Returns f(...f(f(r, t[1]), t[2]), ...), t[n])...).


*tabutil.foldr(t, f, r)*

Returns f(t[1], f(t[2], f(... f(t[n], r)...).


*tabutil.filter(t, f)*

Returns a new array containing all elements t[i] of t for which f(t[i]) tests true.


*tabutil.take(t, n)*

Returns an array containing the first _n_ elements of t.


*tabutil.drop(t, n)*

Returns an array containing all but the first _n_ elements of t.


*tabutil.append(t1, t2)*

Appends all elements of t2 to t1 and returns t1.


*tabutil.rotate(t, n)*

Rotate all elements of _t n_ places to the left (towards lower indices) and return t.

Example:

    tabutil.rotate({1, 2, 3, 4, 5, 6, 7}, 2) -> {3, 4, 5, 6, 7, 1, 2}


**Complex functions:**

*tabutil.comprehend(ts, f)*

Generates a list of all combinations of the elements of the arrays found in _ts_.
If _f_ is specified then it is called for each such combination and the result of the function call (if
not nil) is placed in the list instead.

Each combination is a table whose keys correspond to the keys of _ts_. The values of the
highest numerical key change fastest, those of non-numerical keys change slowest.

Example:

    tabutil.comprehend { {1, 2}, {4, 5}, a = {7, 8} }
    -->
    {
        {1, 4, a = 7},
        {1, 5, a = 7},
        {2, 4, a = 7},
        {2, 5, a = 7},
        {1, 4, a = 8},
        {1, 5, a = 8},
        {2, 4, a = 8},
        {2, 5, a = 8}
    }

*tabutil.tcompare(t1, t2[, depth])*

Compares two tables for equality of contents to a specified depth (default 50).
All non-table entries are compared for exact equality; no conversions are performed.

Down to the specified depth, tables are considered equal if their contents are equal (according
to tcompare). At the depth limit tables are only equal if they are the same table.


*tabutil.numericlt(a, b)*

Performs numeric comparison of strings a and b. Strings of decimal digits within the strings are compared
according to their numeric value rather than string value.
Returns true if a < b.

*tabutil.spairs(t, flags)*

Sorted pairs. Performs the same function as pairs (but slower of course) except that
the keys are sorted and optionally filtered. Direction of sorting can be selected.
By default the keys are sorted using '<'; a different comparison function can be
supplied.


*tabutil.gtable(iter, state, value)*

Returns a table containing all values (first return value only) generated by the iterator function iter, called as iter(state, value).

Example:

    tabutil.gtable(string.gmatch("abc def,   ghi", "%a+"))
    -->
    {"abc", "def", "ghi"}


*tabutil.g2table(iter, state, value)*

The same function as _tabutil.gtable()_, except that the second return value of the iterator function is collected.

*tabutil.ginline(iter, state, value)*

Returns inline all values (first return value only) generated by the iterator function iter, called as iter(state, value).

Example:

    tabutil.ginline(string.gmatch("abc def,   ghi", "%a+"))
    -->
    "abc" "def" "ghi"

*tabutil.g2inline(iter, state, value)*

The same function as _tabutil.ginline()_, except that the second return value of the iterator function is collected.


*tabutil.ivalues(t)

Returns all values in array t (like ipairs, but without the keys).



### tabular.lua

**local tabular = require "geneas.tabular"**

This module contains some high-level table operations:


*tabular.unify(ts[, flags])*

Recursively unifies the array of tables found in *ts*. Similar to the unionfs file system, the returned table appears to
contain all table entries found in any of the component tables, with entries in earlier tables
taking priority over those in later tables in the case of identical keys.

The result of a call to tabular.unify is called a unification. It is an empty table whose contents are generated dynamically via metamethods. If the contents of the component tables change after the unification has been created then the contents of the unification will also change accordingly. Note that in general sub-tables of a unification are also unifications (see below).

Sub-tables of the same name are recursively unified; however if one component table contains a non-table member of the same name then tables of that name in later components are 'shadowed' and are not included in the sub-unification. Recursive unification of sub-tables is only performed up to a maximum depth; when the maximum depth is reached a simple table is returned containing the first value found in the array of component tables for each key. The maximum depth defaults to 50 and can be set via *maxdepth=num* in the flags parameter or in *ts.maxdepth*.

The unified table will be writable if the option *writable* is specified in the optional flags parameter or *ts.writable* is true. Any data written to a unification is stored in the first table. Thus by putting an empty table first in the list, all updates can be captured and the other tables remain unchanged.

When a writable unification is created, an extra hidden table (the 'mask' table) is inserted internally into the list of tables in second place. When data is written to the unification the mask table is also updated to hide the previous (unified) contents.

The contents of the mask table can be retrieved by calling the unification with the parameter "mask". Overwritten or deleted items are stored in this table with the special internal value *tabular.NIL*, which is translated into nil when the table is read; this value can also be explic itly used in the source tables to mask data in later tables.

The _flags_ parameter may be a table of key-value pairs or a string of comma-separated flag specifications. If flags is a number it is interpreted as the value of maxdepth. If flags is a boolean then it is interpreted as the value of writable.

Caveat: when using Lua 5.1, iteration over unifications using *pairs()* will not work out of the box, since the *\_\_pairs* metamethod is not recognized. To enable iteration over unified tables in Lua 5.1 the global *pairs* function should be replaced by the function *tabular.upairs* (\_G.pairs = tabular.upairs).

Example:

    x = {}
    y = { a = 1, b = 2 }
    z = { b = { p = 1, q = 2 }, c = 4 }
    t = tabular.unify { x, y, z, writable = true }
    for k,v in pairs(t) do print(k .. "=" .. v) end -- -> a=1, b=2, c=4
    t.a = 5
    t.c = nil -- now x = { a = 5 } and t.c = nil
    t("mask") -- -> { c = NIL }

Note: to display the contents of a unification using the _dump_ function (see above) the 'cooked' flag must be set, and optionally 'nometa' to hide the machinery.


*tabular.upairs(t)*

If parameter _t_ is a unification then returns t("pairs"), otherwise passes the parameter to Lua's built-in pairs function.

*tabular.NIL*

Special table value used by *unify*. When read will return the value nil.


*tabular.isunification(v)*

Returns true if v is a unification.


*tabular.istable(v)*

Returns true if v is a table and not NIL.


*tabular.isvalue(v)*

Returns true if v is not a table and not nil.


*tabular.getfield(t, k)*

Accesses table t using a 'structured' key k. The key is a string consisting of a
concatenation of string keys ".<key>" and numerical keys "[key]".

Thus for example if key = "left[1][2].right" then the value t.left[1][2].right
is returned. If any intermediate key does not exist or its value is not a table then nil
is returned.


*tabular.putfield(t, k, v)*

Writes to a table using a 'structured' key as for getfield(). Intermediate tables
are created as required; if an intermediate key exists but is not a table then it
is replaced with a table.


*tabular.fields(t[, depth[, selector]])*

Returns an array containing the structured keys of all entries in t to the specified
depth (or no limit if not specified). If a selector is specified then only those keys which match the
selector are returned. Keys which are neither strings nor numbers are ignored.


*tabular.deepcopy(t, map, ctrl)*

Returns a deep copy of t. The depth of copy may be limited and a mapping table between
the original items and the copies is generated; this may be passed to a later call so
that the mapping can be reproduced.


### class.lua

**local class = require "geneas.class"**

Implements a simple class/object infrastructure. See modules xpm.lua and mpi.lua for examples of usage.

*class(cls)*

Converts table _cls_ into a class object and returns it. Objects of this class will have table _cls_ as their metatable, so it should contain any required metamethods.
The table should also contain an entry _name_ specifying the name of the class. This will be returned by the class.type() function.
Methods of class objects should be specified in a sub-table __index.

If the table contains a function entry _init_ then this function will be called when objects of the class are created. 

After the class has been registered objects of this class can be created by calling the class object. Any parameters will be passed to the init function (if any). If a class has no init function then the class object must be called with a table as parameter, which will be converted directly into the object.

The init function is called with an object of the class as first parameter, followed by all arguments to the call to the class object. The first parameter is an empty object unless the first argument of the call is a simple table (ie not an object), in which case this table is converted into an object (by setting its metatable) and passed as the first parameter.

The init function may return the already created object or a new table. In the latter case the original object is deleted and the returned table is converted to an object by setting its metatable. A nil return value is equivalent to returning the original object.

This allows the init function to perform initialization and/or checking of the parameters according to the requirements of the class.

*class.classof(obj)*

If _obj_ is a member of a class created by this module then this function returns its class object (ie, metatable), otherwise returns nil.

*class.type(obj)*

Returns the type of _obj_ as a string. If _class.classof(obj)_ returns nil (ie the object is not a member of a class created by this module) then the value of the global function _type(obj)_ is returned. Otherwise the name of the class (cls.name) prefixed by "class " is returned. If it is a class object then "class class" is returned.


### xpm.lua

**local xpm = require "geneas.xpm"**

A simple class for generating XPM image files.

Character codes for colours can be assigned explicitly or automatically. Graphical data
can be written either line by line or pixel by pixel from top to bottom.

*xpm(filename, width, height[, cpp])*

*xpm{[name = filename], [width = width], [height = height], [cpp = cpp]}

Create a new XPM object with the given filename and width and height in pixels. The size of the character code (_cpp_) for each pixel may be specified and defaults to 1.

The second form allows the specification of filename, width and height to be deferred until the file is opened (see _xpm:open()_ below). If characters-per-pixel is not equal to 1 then it must be set here.

*xpm:defcolour(colour[, symbol])*

Define a colour and return its symbol as a lua string. The symbol may be specified in which case it must not already be defined, or if so, the colour must match the current definition.

Colours may be specified as a string in the usual format '#rrggbb", or as a table containing RGB or HSV data.

An RGB colour table must contain members _r, g, and b_ and optionally _range_. If no range is given then the components are assumed to be in the range 0..1, otherwise 0..range.

An HSV colour table must contain members _h, s, v_ and _hsv_=true. Components are in the range 0..1 unless member _range_ is specified as for RGB data. Member _hrange_ may also be specified for hue and overrides the value in _range_. Hue values are encoded as 0 = red, 1/3 = green and 2/3 = blue.


*xpm:open([filename[, width[, height]]])*

Creates the XPM file and writes the header. Note that all colours _must_ be defined before _open()_ is called. The filename, width and height may be specified here.

*xpm:putpixel(pixel)*

Writes a single pixel to the current line. The parameter _pixel_ is the character code for the required colour.

*xpm:putline(line)*

Flushes any pixel data that may have been written via _putpixel_, appends the data in parameter _line_, and terminates the current line of picture data. The line data may be either a single string of concatenated pixels or an array of pixels.

Note that no checking or padding of line lengths is performed; it is up to the caller to ensure that the correct number of pixels are written in each line, and that the correct number of lines are written.


*xpm:close()*

Writes the file trailer and closes the XPM file.



### mpi.lua

**local mpi = require "geneas.mpi"**

A multiprecision integer arithmetic class implemented in pure lua.

Big integers are stored as arrays of digits in lua tables, where each digit contains 31 bits of data.
Metamethods are defined so that mpi objects can be used in
arithmetic expressions in conjunction with lua numbers.

Mainly useful for experimental purposes, as the performance cannot compare to a third-party
library such as gmp.

Under lua 5.1 and 5.2 the mpi module makes use of the bit32 module if available. If bit32 is not available then some operations will be slower and logical bit operations will not be available at all.

**constructor:**

*mpi(value)*

Returns a new mpi object. The value parameter may be any of the following:

* a lua number (if non-integral then the fractional part will be silently ignored);
* a string, interpreted as a decimal number unless preceded by 0x for hex or 0 for octal;
* an mpi object; a new mpi object with the same value is returned.

**metamethods:**

Metamethods are defined for tostring, concat and all arithmetic, shift, bit (except '^') and comparison operations, and so may be used in the same way as lua numbers in most cases. Under lua 5.3 the fractional division operator '/' (__div) is not allowed by default; only the integer operator '//' (__idiv) is defined. This can be overridden via _mpi.setconfig()_ (see below).

**object methods:**

_mpi:tonumber()_

Returns the mpi value as a lua number. If the value fits into a lua integer then an integer is returned, otherwise a floating point value.

_mpi:tostring([radix[, lc[, sep]]])_

Returns the mpi value as a string using the specified radix (default 10). For radix greater than 10 upper case characters are used unless lc evaluates true. If sep is specified then mpi digit groups may be separated by this string when converting to hex (for test purposes only; see _mpi.setdigit()_ below)

_mpi:length()_

Returns the number of mpi digits.

_mpi:sigplaces()_

Returns the number of significant bits. This may be interpreted as 1+floor(log2(n)).

_mpi:extract(pos)_

Extract up to two mpi digits (by default, 62 bits) of MSB data, or at position _pos_.

**class methods**

All meta-operations are also available as static methods:

_mpi.add(a, b)_

Returns the sum of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.sub(a, b)_

Returns the difference of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.mul(a, b)_

Returns the product of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.div(a, b)_

Returns the integer quotient of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.mod(a, b)_

Returns a modulo b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.pow(a, b)_

Returns a to the power b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.eq(a, b)_

Returns true if mpi(a) == mpi(b).

_mpi.lt(a, b)_

Returns true if mpi(a) < mpi(b).

_mpi.le(a, b)_

Returns true if mpi(a) <= mpi(b).

_mpi.ne(a, b)_

Returns true if mpi(a) ~= mpi(b).

_mpi.gt(a, b)_

Returns true if mpi(a) > mpi(b).

_mpi.ge(a, b)_

Returns true if mpi(a) >= mpi(b).

_mpi.band(a, b)_

Returns the bitwise AND of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.bor(a, b)_

Returns the bitwise OR of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.bxor(a, b)_

Returns the bitwise XOR of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.shl(a, b)_

Returns mpi(a) shifted left b bits (if b < 0 then right shift). a and b may be mpi objects or lua numbers.

_mpi.shr(a, b)_

Returns mpi(a) shifted right b bits (if b < 0 then left shift). a and b may be mpi objects or lua numbers.


_mpi.cmp(a, b)_

Returns 0 if a == b, a negative number if a < b and a positive number if a > b. a and b may be mpi objects or lua numbers.

_mpi.neg(m)_

Returns m negated as an mpi object. m may be an mpi object or a lua number.

_mpi.divmod(a, b[, mode])_

Returns the quotient (a // b) and remainder (a % b) of a integer-divided by b. If mode tests false then the remainder has the same sign as b (modulo division). If mode tests true then the remainder has the same sign as a (quotient truncation to zero). a and b may be mpi objects or lua numbers. If b is an mpi object then the remainder is returned as an mpi object, otherwise the remainder is returned as a lua number.

_mpi.divrem(a, b)_

The is the same as mpi.divmod called with mode == true.

_mpi.isqrt(m)_

Returns the integer square root of a as an mpi object; ie the largest integer s such that s^2 <= m. m may be an mpi object or a lua number.

_mpi.gcd(a, b)_

Returns the greatest common divisor of a and b as an mpi object. a and b may be mpi objects or lua numbers.

_mpi.factorial(x)_

Returns x! as an mpi object. x must be convertible to an mpi object.

_mpi.read(str, radix)_

Convert str to an mpi object using the specified radix (2..36)

**module configuration:**

These function control the static properties of the mpi implementation and should only be called immediately after the module has been loaded. Changes to the module configuration may render existing mpi objects invalid. These functions are only useful for testing and experimental purposes.

_mpi.setdigit(d)_

Set the size of the mpi digit to 2^d. The default (d == nil) and maximum value is 31, since a lua number, which is 63 bits plus sign, must be able to hold the product of two digits. (Note: in the lua 5.1/5.2 version the default and maximum value is 25).

If the digit size is a multiple of four bits then conversion of mpi objects to hexadecimal string format is optimized by writing each mpi digit as a hex number and concatenating. In this case the digits will by default be separated by a ':' character (this can be disabled by calling setconfig).

If a zero or negative value is specified then the mpi module operates in a special decimal mode, in which the mpi digit is given by 10^(-d). If d == 0 then the default value of -9 is used (-7 for lua 5.1/5.2). This mode is operationally the same except that the shift operators and shift functions operate on decimal digits rather than bits; ie in decimal mode *mpi(123) << 1 = 1230*. Also, the logical bit operations (&, |, ^) are not meaningful in decimal mode.
When converting to decimal string format the mpi digits are separated by ',' characters.

_mpi.setconfig(c)_

Set module configuration parameters defined in table _c_ as follows.

**c.setdigit=*num***

Same as calling _mpi.setdigit(num)_.

**c.separator=*str***

Set the separator for optimized string conversion to _str_, which may be empty.

**c.divslash=*boolean***

If set to _true_ then the fractional division operator '/' may be used as alias for '//' (lua 5.3 only)

**c.paranoid=*boolean***

If set to _true_ then additional internal checks are enabled.

_mpi.getconfig()_

Returns a table containing the current module configuration, including some derived values:

    {
      setdigit           (number) the value passed to mpi.setdigit()
      unit               (number) the size of the digit base unit (2 or 10)
      width              (number) number of base units per digit (31 or 25 by default)
      decs_per_digit     (number or nil) == width iff in decimal mode
      bits_per_digit     (number or nil) == width iff in binary mode
      separator          (string) digit separator
      paranoid           (boolean) true if paranoid
      divslash           (boolean) true if '/' operator can be used for division
      bitops             (boolean) true if logical bit operations are valid
    }
