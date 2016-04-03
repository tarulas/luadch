--[[

        util.lua by blastbeat and pulsar

            - this script is a collection of useful functions

            v0.12: by tarulas
                - changed: util.generatepass( len )
                    - password generation needs a CSPRNG, not math.random crap
                - added: pairsbykeys( tbl, sortby )

            v0.11: by pulsar
                - added: maketable( tbl, path )
                    - make a new local table file

            v0.10: by pulsar
                - added: spairs( tbl )
                    - sort table by string keys - based on a sample by http://lua-users.org

            v0.09: by pulsar
                - improved out_error messages

            v0.08: by pulsar
                - added: util.getlowestlevel( tbl )
                    - get lowest level with rights from permission table (for help/ucmd)

            v0.07: by pulsar
                - added: util.trimstring( str )
                    - trim whitespaces from both ends of a string
                - changed: util.formatbytes( bytes )
                    - return nil, err if parameter is not valid
                - changed: util.formatseconds( t )
                    - return nil, err if parameter is not valid

            v0.06: by pulsar
                - changed: util.difftime( t1, t2 )
                    - return complete time in seconds as first arg

            v0.05: by pulsar
                - changed: util.generatepass( len )
                    - increase default password length to 20
                - added: util.date( )
                - added: util.difftime( t1, t2 )
                - added: util.convertepochdate( t )

            v0.04: by pulsar
                - removed unneeded loop

            v0.03: by blastbeat
                - small changes in function: formatbytes()
                - small changes in function: generatepass()

            v0.02: by pulsar
                - add function: generatepass( len )  / based on a function by blastbeat
                    - usage: number/nil = util.generatepass( len )
                        - returns a random alphanumerical password with length = len
                        - returns nil if len = nil  or  len > 1000
                - add function: formatbytes( bytes )  / based on a function by Night
                    - usage: string/nil = util.formatbytes( bytes )
                        - returns converted bytes as a sting e.g. "209.81 GB"
                        - returns nil if bytes = nil

            v0.01: by blastbeat

]]--

----------------------------------// DECLARATION //--

--// lua functions //--

local type = use "type"
local table = use "table"
local pairs = use "pairs"
local ipairs = use "ipairs"
local tostring = use "tostring"
local tonumber = use "tonumber"
local loadstring = use "loadstring"
local setmetatable = use "setmetatable"

--// lua libs //--

local io = use "io"
local math = use "math"
local string = use "string"
local os = use "os"

--// lua lib methods //--

local io_open = io.open
local os_time = os.time
local os_date = os.date
local os_difftime = os.difftime
local math_floor = math.floor
local math_fmod = math.fmod
local table_sort = table.sort
local table_insert = table.insert
local table_concat = table.concat
local string_byte = string.byte
local string_format = string.format
local string_find = string.find
local string_match = string.match

--// extern libs //--

local adclib = use "adclib"
local unicode = use "unicode"

--// extern lib methods //--

local isutf8 = adclib.isutf8
local ascii_sub = unicode.ascii.sub
local utf_format = unicode.utf8.format
local ascii_gsub = unicode.ascii.gsub

--// core scripts //--

local out

local doc = use "doc"
local mem = use "mem"

--// core methods //--

local out_put
local out_error

--// constants //--

--// functions //--

local init

local handlebom
local checkfile

local serialize
local sortserialize

local loadtable
local savetable
local savearray
local maketable

local formatseconds
local formatbytes
local generatepass

local date
local difftime
local convertepochdate

local trimstring
local getlowestlevel
local spairs
local pairsbykeys

--// tables //--

--// simple data types //--

local _
local _bom


----------------------------------// DEFINITION //--

_bom = string.char( 239 ) .. string.char( 187 ) .. string.char( 191 )

init = function( )
    out = use "out"
    out_put = out.put
    out_error = out.error
end

handlebom = function( str )
    if type( str ) == "string" and ascii_sub( str, 1, 3 ) == _bom then
        str = ascii_sub( str, 4, -1 )
        return str, true
    else
        return str, false
    end
end

checkfile = function( path )
    local script, err = io_open( path, "r" )
    if script then
        local content = script:read "*a"
        local chunk, bol = handlebom( content )    -- cut possible signature
        script:close( )
        if not isutf8( chunk or "" ) then    -- utf check to avoid format errors
            out_error( "util.lua: function 'checkfile': error in ", path, ": no utf8 format (checkfile)" )
            return nil, nil, "no utf8 format"
        elseif bol then
            --script = io_open( path, "w+" )
            --script:write( chunk )    -- write without signature
            --script:close( )
            --return chunk, content, ( "deleted utf8 bom in " .. path )
            return chunk, content
        end
        return chunk, content
    end
    out_error( "util.lua: function 'checkfile': error in ", path, ": ", err, " (checkfile)" )
    return nil, nil, err
end

serialize = function( tbl, name, file, tab )  -- this function saves a table to a file
    tab = tab or ""
    file:write( tab .. name .. " = {\n\n" )
    for key, value in pairs( tbl ) do
        local key = type( key ) == "string" and utf_format( "[ %q ]", key ) or utf_format( "[ %d ]", key )
        if type( value ) == "table" then
            serialize( value, key, file, tab .. "    " )
        else
            local value = type( value ) == "string" and utf_format( "%q", value ) or tostring( value )
            file:write( tab .. "    " .. key .. " = " .. value )
        end
        file:write( ",\n" )
    end
    file:write( "\n" .. tab .. "}" )
end

sortserialize = function( tbl, name, file, tab, r )
    tab = tab or ""
    local temp = { }
    for key, k in pairs( tbl ) do
        --if type( key ) == "string" or "number" then
            table_insert( temp, key )
        --end
    end
    table_sort( temp )
    local str = tab .. name
    if r then
        file:write( str .. " {\n\n" )
    else
        file:write( str .. " = {\n\n" )
    end
    for k, key in ipairs( temp ) do
        if ( type( tbl[ key ] ) ~= "function" ) then
            local skey = ( type( key ) == "string" ) and utf_format( "[ %q ]", key ) or utf_format( "[ %d ]", key )
            if type( tbl[ key ] ) == "table" then
                sortserialize( tbl[ key ], skey, file, tab .. "    " )
                file:write( ",\n" )
            else
                local svalue = ( type( tbl[ key ] ) == "string" ) and utf_format( "%q", tbl[ key ] ) or tostring( tbl[ key ] )
                file:write( tab .. "    " .. skey .. " = " .. svalue )
                file:write( ",\n" )
            end
        end
    end
    file:write( "\n" )
    file:write( tab .. "}" )
end

--// loads a local table from file
loadtable = function( path )
    local content, original, err = checkfile( path )
    if not content then
        return nil, err
    end
    local chunk, error = loadstring( content )
    if chunk then
        local ret = chunk( )
        if ret and type( ret ) == "table" then
            return ret, err
            --return ret
        else
            return nil, "invalid table"
        end
    end
    return nil, error
end

--// saves a table to a local file
savetable = function( tbl, name, path )
    local file, err = io_open( path, "w+" )
    if file then
        file:write( "local " .. name .. "\n\n" )
        sortserialize( tbl, name, file, "" )
        file:write( "\n\nreturn " .. name )
        file:close( )
        return true
    else
        out_error( "util.lua: function 'savetable': error in ", path, ": ", err, " (savetable)" )
        return false, err
    end
end

--// saves an array to a local file
savearray = function( array, path )
    array = array or { }
    local file, err = io_open( path, "w+" )
    if not file then
        out_error( "util.lua: function 'savearray': error in ", path, ": ", err, " (savearray)" )
        return false, err
    end
    local iterate, savetbl
    iterate = function( tbl )
        local tmp = { }
        for key, value in pairs( tbl ) do
            tmp[ #tmp + 1 ] = tostring( key )
        end
        table_sort( tmp )
        for i, key in ipairs( tmp ) do
            key = tonumber( key ) or key
            if type( tbl[ key ] ) == "table" then
                file:write( ( ( type( key ) ~= "number" ) and tostring( key ) .. " = " ) or " " )
                savetbl( tbl[ key ] )
            else
                file:write( ( ( type( key ) ~= "number" and tostring( key ) .. " = " ) or "" ) .. ( ( type( tbl[ key ] ) == "string" ) and utf_format( "%q", tbl[ key ] ) or tostring( tbl[ key ] ) ) .. ", " )
            end
        end
    end
    savetbl =  function( tbl )
        local tmp = { }
        for key, value in pairs( tbl ) do
            tmp[ #tmp + 1 ] = tostring( key )
        end
        table_sort( tmp )
        file:write( "{ " )
        iterate( tbl )
        file:write( "}, " )
    end
    file:write( "return {\n\n" )
    for i, tbl in ipairs( array ) do
        if type( tbl ) == "table" then
            file:write( "    { " )
            iterate( tbl )
            file:write( "},\n" )
        else
            file:write( "    " .. utf_format( "%q", tostring( tbl ) ).. ",\n" )
        end
    end
    file:write( "\n}" )
    file:close( )
    return true
end

--// make a new local table file
maketable = function( name, path )
    local t = {}
    if not path or path == "" then
        local err = "util.lua: function 'maketable': missing param: path"
        return false, err
    end
    local file, err = io_open( path, "w" )
    if not file then
        out_error( "util.lua: function 'maketable': error in ", path, ": ", err, " (maketable)" )
        return false, err
    else
        if not name or name == "" then
            file:write( "return {\n\n" )
            file:write( "}" )
        else
            file:write( "local " .. name .. "\n\n" )
            file:write( name .. " = {\n\n}" )
            file:write( "\n\nreturn " .. name )
        end
        file:close()
    end
    return true
end

--// converts seconds to: days, hours, minutes, seconds
formatseconds = function( t )
    local err
    local t = tonumber( t )
    if not t then
        err = "util.lua: error: number expected, got nil"
        return nil, err
    end
    if not type( t ) == "number" then
        err = "util.lua: error: number expected, got " .. type( t )
        return nil, err
    end
    if ( t < 0 ) or ( t == 1 / 0 ) then
        err = "util.lua: error: parameter not valid"
        return nil, err
    end
    return
        math_floor( t / ( 60 * 60 * 24 ) ),
        math_floor( t / ( 60 * 60 ) ) % 24,
        math_floor( t / 60 ) % 60,
        t % 60
end

--// convert bytes to the right unit  / based on a function by Night
formatbytes = function( bytes )
    local err
    local bytes = tonumber( bytes )
    --if ( not bytes ) or ( not type( bytes ) == "number" ) or ( bytes < 0 ) or ( bytes == 1 / 0 ) then
    if not bytes then
        err = "util.lua: error: number expected, got nil"
        return nil, err
    end
    if not type( bytes ) == "number" then
        err = "util.lua: error: number expected, got " .. type( bytes )
        return nil, err
    end
    if ( bytes < 0 ) or ( bytes == 1 / 0 ) then
        err = "util.lua: error: parameter not valid"
        return nil, err
    end
    if bytes == 0 then return "0 B" end
    local i, units = 1, { "B", "KB", "MB", "GB", "TB", "PB", "EB", "YB" }
    while bytes >= 1024 do
        bytes = bytes / 1024
        i = i + 1
    end
    if units[ i ] == "B" then
        return string_format( "%.0f", bytes ) .. " " .. ( units[ i ] or "?" )
    else
        return string_format( "%.2f", bytes ) .. " " .. ( units[ i ] or "?" )
    end
end

--// returns a random generated alphanumerical password with length = len; if no param is specified then len = 20
local _base62 = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
                  "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
                  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" }
generatepass = function( len )
    local len = tonumber( len )
    if not ( type( len ) == "number" ) or ( len < 0 ) or ( len > 1000 ) then len = 20 end
    local randomdevice = io_open( "/dev/urandom", "r" )
    local _buffer = {}
    local r = 0
    for i = 1, len do
        repeat
            r = string_byte( randomdevice:read( 1 ) )
        until ( r < 248 ) -- 248 = 256-(256%62), to avoid bias
        _buffer[ i ] = _base62[ math_fmod( r, 62 ) + 1 ]
    end
    r = 0
    randomdevice:close( )
    return table_concat( _buffer )
end

--// returns current date in new luadch date style: yyyymmddhhmmss (as number)
date = function()
    local year = os_date( "%Y" )
    local month = os_date( "%m" )
    local day = os_date( "%d" )
    local hour = os_date( "%H" )
    local minutes = os_date( "%M" )
    local seconds = os_date( "%S" )
    return tonumber( year .. month .. day .. hour .. minutes .. seconds )
end

--// returns difftime between two date values (new luadch date style)
difftime = function( t1, t2 )
    local err
    local t1 = tonumber( t1 )
    local t2 = tonumber( t2 )
    if not t1 then
        err = "util.lua: error in param #1: got nil"
        return nil, err
    end
    if not t2 then
        err = "util.lua: error in param #2: got nil"
        return nil, err
    end
    if type( t1 ) ~= "number" then
        err = "util.lua: error in param #1: number expected, got " .. type( t1 )
        return nil, err
    end
    if type( t2 ) ~= "number" then
        err = "util.lua: error in param #2: number expected, got " .. type( t2 )
        return nil, err
    end
    local t1, t2 = tostring( t1 ), tostring( t2 )
    local y1, m1, d1, h1, M1, s1
    local y2, m2, d2, h2, M2, s2
    local diff, T1, T2
    local y, d, h, m, s
    if #t1 ~= 14 then
        err = "util.lua: error in param #1: not valid"
        return nil, err
    else
        y1 = t1:sub( 1, 4 )
        m1 = t1:sub( 5, 6 )
        d1 = t1:sub( 7, 8 )
        h1 = t1:sub( 9, 10 )
        M1 = t1:sub( 11, 12 )
        s1 = t1:sub( 13, 14 )
    end
    if #t2 ~= 14 then
        err = "util.lua: error in param #2: not valid"
        return nil, err
    else
        y2 = t2:sub( 1, 4 )
        m2 = t2:sub( 5, 6 )
        d2 = t2:sub( 7, 8 )
        h2 = t2:sub( 9, 10 )
        M2 = t2:sub( 11, 12 )
        s2 = t2:sub( 13, 14 )
    end
    T1 = os_time( { year = y1, month = m1, day = d1, hour = h1, min = M1, sec = s1 } )
    T2 = os_time( { year = y2, month = m2, day = d2, hour = h2, min = M2, sec = s2 } )
    diff = os_difftime( T1, T2 )
    y = math_floor( diff / ( 60 * 60 * 24 ) / 365 )
    d = math_floor( diff / ( 60 * 60 * 24 ) ) % 365
    h = math_floor( diff / ( 60 * 60 ) ) % 24
    m = math_floor( diff / 60 ) % 60
    s = diff % 60
    return diff, y, d, h, m, s
end

--// convert os.time() "epoch" date to luadch date style: yyyymmddhhmmss (as number)
convertepochdate = function( t )
    local err
    local t = tonumber( t )
    if type( t ) ~= "number" then
        err = "util.lua: error: number expected, got " .. type( t )
        return nil, err
    end
    local date, y, m, d, h, M, s
    date = os_date( "*t", t )
    y = tostring( date.year )
    m = tostring( date.month )
    d = tostring( date.day )
    h = tostring( date.hour )
    M = tostring( date.min )
    s = tostring( date.sec )
    if #m == 1 then m = "0" .. m end
    if #d == 1 then d = "0" .. d end
    if #h == 1 then h = "0" .. h end
    if #M == 1 then M = "0" .. M end
    if #s == 1 then s = "0" .. s end
    return tonumber( y .. m .. d .. h .. M .. s ), err
end

--// trim whitespaces from both ends of a string
trimstring = function( str )
    local err
    local str = tostring( str )
    if type( str ) ~= "string" then
        err = "util.lua: error: string expected, got " .. type( str )
        return nil, err
    end
    return string_find( str, "^%s*$" ) and "" or string_match( str, "^%s*(.*%S)" )
end

--// get lowest level with rights from permission table (for help/ucmd)
getlowestlevel = function( tbl )
    local err
    local lowest = 100
    for k, v in pairs( tbl ) do
        if type( k ) ~= "number" then
            err = "util.lua: error: number expected for key, got " .. type( k )
            return nil, err
        end
        if not ( ( type( v ) == "number" ) or ( type( v ) == "boolean" ) ) then
            err = "util.lua: error: number or boolean expected for value, got " .. type( v )
            return nil, err
        end
        if type( v ) == "number" then if v > 0 then if k < lowest then lowest = k end end end
        if type( v ) == "boolean" then if v then if k < lowest then lowest = k end end end
    end
    return lowest
end

--// sort table by string keys - based on a sample by http://lua-users.org
spairs = function( tbl )
    local err
    if type( tbl ) ~= "table" then
        err = "util.lua: error: table expected, got " .. type( tbl )
        return nil, err
    end
    local genOrderedIndex = function( tbl )
        local orderedIndex = {}
        for key in pairs( tbl ) do table_insert( orderedIndex, key ) end
        table_sort( orderedIndex )
        return orderedIndex
    end
    local orderedNext = function( tbl, state )
        local key = nil
        if state == nil then
            tbl.orderedIndex = genOrderedIndex( tbl )
            key = tbl.orderedIndex[ 1 ]
        else
            for i = 1, #tbl.orderedIndex do
                if tbl.orderedIndex[ i ] == state then key = tbl.orderedIndex[ i + 1 ] end
            end
        end
        if key then return key, tbl[ key ] end
        tbl.orderedIndex = nil
        return
    end
    return orderedNext, tbl, nil
end

--// pairs by keys iterator (see Programming in Lua, 19.3)
pairsbykeys = function( tbl, sortby )
    local a = {}
    for n in pairs( tbl ) do table_insert( a, n ) end
        table_sort( a, sortby )
        local i = 0
        local iter = function( )
            i = i + 1
            if a[ i ] == nil then return nil
            else return a[ i ], tbl[ a[ i ] ]
        end
    end
    return iter
end

----------------------------------// PUBLIC INTERFACE //--

return {

    init = init,

    handlebom = handlebom,
    checkfile = checkfile,
    savetable = savetable,
    loadtable = loadtable,
    serialize = serialize,
    savearray = savearray,
    formatseconds = formatseconds,
    formatbytes = formatbytes,
    generatepass = generatepass,
    date = date,
    difftime = difftime,
    convertepochdate = convertepochdate,
    trimstring = trimstring,
    getlowestlevel = getlowestlevel,
    spairs = spairs,
    pairsbykeys = pairsbykeys,
    maketable = maketable,

}
