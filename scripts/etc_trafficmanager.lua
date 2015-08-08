﻿--[[

    etc_trafficmanager.lua by pulsar

        based on my etc_transferblocker.lua

        usage:

        [+!#]trafficmanager block ds <NICK>  -- blocks downloads (d) and search (s)
        [+!#]trafficmanager block dus <NICK>  -- blocks downloads (d), uploads (u) and search (s)
        [+!#]trafficmanager unblock <NICK>  -- unblock user
        [+!#]trafficmanager show settings  -- shows current settings from "cfg/cfg.tbl"
        [+!#]trafficmanager show blocks  -- shows all blockes users and her blockmodes

        v0.7:
            - small bugfix  / thx Mocky

        v0.6:
            - check if target is a bot  / thx Kaas
            - fix "msg_notonline"  / thx Sopor
            - add "is_blocked()"
                - fix double block issue  / thx Sopor

        v0.5:
            - possibility to block/unblock single users from userlist  / requested by Sopor
            - show list of all blocked users
            - show settings
            - show blockmode in user description
            - add new table lookups, imports, msgs
            - rewrite some parts of code

        v0.4:
            - possibility to block users with 0 B share

        v0.3:
            - small fix in "onLogin" listener
                - remove return PROCESSED
                - add return nil

        v0.2:
            - add missing permission check  / thx Kaas

        v0.1:
            - option to block download for specified levels
            - option to block upload for specified levels
            - option to block search for specified levels

]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_trafficmanager"
local scriptversion = "0.7"

local cmd = "trafficmanager"
local cmd_b = "block"
local cmd_u = "unblock"
local cmd_s = "show"

local block_file = "scripts/data/etc_trafficmanager.tbl"


----------------------------
--[DEFINITION/DECLARATION]--
----------------------------

--// table lookups
local cfg_get = cfg.get
local hub_debug = hub.debug
local hub_import = hub.import
local hub_getbot = hub.getbot()
local hub_isnickonline = hub.isnickonline
local hub_getusers = hub.getusers
local hub_escapeto = hub.escapeto
local hub_sendtoall = hub.sendtoall
local utf_format = utf.format
local utf_match = utf.match
local utf_len = utf.len
local utf_sub = utf.sub
local util_loadtable = util.loadtable
local util_savetable = util.savetable
local util_getlowestlevel = util.getlowestlevel

--// imports
local activate = cfg_get( "etc_trafficmanager_activate" )
local permission = cfg_get( "etc_trafficmanager_permission" )

local report = cfg_get( "etc_trafficmanager_report" )
local report_hubbot = cfg_get( "etc_trafficmanager_report_hubbot" )
local report_opchat = cfg_get( "etc_trafficmanager_report_opchat" )
local llevel = cfg_get( "etc_trafficmanager_llevel" )

local blocklevel_tbl = cfg_get( "etc_trafficmanager_blocklevel_tbl" )
local sharecheck = cfg_get( "etc_trafficmanager_sharecheck" )
local oplevel = cfg_get( "etc_trafficmanager_oplevel" )
local block_ctm = cfg_get( "etc_trafficmanager_block_ctm" )
local block_rcm = cfg_get( "etc_trafficmanager_block_rcm" )
local block_sch = cfg_get( "etc_trafficmanager_block_sch" )
local login_report = cfg_get( "etc_trafficmanager_login_report" )
local report_main = cfg_get( "etc_trafficmanager_report_main" )
local report_pm = cfg_get( "etc_trafficmanager_report_pm" )

local opchat = hub_import( "bot_opchat" )
local opchat_activate = cfg_get( "bot_opchat_activate" )

local desc_prefix_activate = cfg_get( "usr_desc_prefix_activate" )
local desc_prefix_permission = cfg_get( "usr_desc_prefix_permission" )
local desc_prefix_table = cfg_get( "usr_desc_prefix_prefix_table" )

--// flags
local flag_ds = "[B:D,S] "
local flag_dus = "[B:D,U,S] "
local flag_lvl, ctm, rcm, sch = "", "", "", ""
if block_ctm then ctm = "D," end
if block_rcm then rcm = "U," end
if block_sch then sch = "S," end
flag_lvl = ctm .. rcm .. sch
flag_lvl = flag_lvl:sub( 0, #flag_lvl - 1 )
flag_lvl = "[B:" .. flag_lvl .. "] "

--// msgs
local scriptlang = cfg_get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or { }; err = err and hub_debug( err )

local help_title = lang.help_title or "etc_trafficmanager.lua - Operators"
local help_usage = lang.help_usage or "[+!#]trafficmanager show settings|show blocks"
local help_desc = lang.help_desc or "Shows current settings from 'cfg/cfg.tbl' | Shows all blockes users and their blockmodes"

local help_title2 = lang.help_title2 or "etc_trafficmanager.lua - Owners"
local help_usage2 = lang.help_usage2 or "[+!#]trafficmanager block ds <NICK>|block dus <NICK>|unblock <NICK>"
local help_desc2 = lang.help_desc2 or "Blocks downloads (d) and search (s) | Blocks downloads (d), uploads (u) and search (s) | Unblock user"

local msg_denied = lang.msg_denied or "You are not allowed to use this command."
local msg_god = lang.msg_god or "You are not allowed to block this user."
local msg_notonline = lang.msg_notonline or "User is offline."
local msg_notfound = lang.msg_notfound or "User not found."
local msg_stillblocked = lang.msg_stillblocked or "The level of this user is already auto-blocked."
local msg_isbot = lang.msg_isbot or "User is a bot."
local msg_block = lang.msg_block or "Traffic Manager: Block user: %s  |  Mode: %s"
local msg_unblock = lang.msg_unblock or "Traffic Manager: Unblock user: %s"
local msg_op_report_block = lang.msg_op_report_block or "Traffic Manager:  %s  has blocked user: %s  |  Mode: %s"
local msg_op_report_unblock = lang.msg_op_report_unblock or "Traffic Manager:  %s  has unblocked user: %s"

local ucmd_menu_ct1_1 = lang.ucmd_menu_ct1_1 or { "Hub", "etc", "Traffic Manager", "show Settings" }
local ucmd_menu_ct1_2 = lang.ucmd_menu_ct1_2 or { "Hub", "etc", "Traffic Manager", "show Blocked users" }
local ucmd_menu_ct2_1 = lang.ucmd_menu_ct2_1 or { "Traffic Manager", "block", "download, search" }
local ucmd_menu_ct2_2 = lang.ucmd_menu_ct2_2 or { "Traffic Manager", "block", "download, upload, search" }
local ucmd_menu_ct2_3 = lang.ucmd_menu_ct2_3 or { "Traffic Manager", "unblock" }

local report_msg = lang.report_msg or [[


=== TRAFFIC MANAGER =====================================

     Hello %s, your level in this hub:  %s [ %s ]

         - Block downloads for your level:  %s
         - Block uploads for your level:  %s
         - Block searches for your level:  %s

===================================== TRAFFIC MANAGER ===
  ]]

local report_msg_2 = lang.report_msg_2 or [[


=== TRAFFIC MANAGER =====================================

     Hello %s, your share: 0  B

         - Block downloads:  %s
         - Block uploads:  %s
         - Block searches:  %s

===================================== TRAFFIC MANAGER ===
  ]]

local report_msg_3 = lang.report_msg_3 or [[


=== TRAFFIC MANAGER =====================================

     Hello %s, your nick is on the blocklist:

         - Block downloads:  %s
         - Block uploads:  %s
         - Block searches:  %s

===================================== TRAFFIC MANAGER ===
  ]]

local opmsg = lang.opmsg or [[


=== TRAFFIC MANAGER =====================================

   Script is active:  %s

         Block downloads:  %s
         Block uploads:  %s
         Block searches:  %s

   Send report to blocked users on login:  %s

         Send to Main:  %s
         Send to PM:  %s

   Blocked levels:

%s
   Block users with 0 B share:  %s

===================================== TRAFFIC MANAGER ===
  ]]

local msg_usage = lang.msg_usage or [[


=== TRAFFIC MANAGER ===========================================================

Usage:

 [+!#]trafficmanager block ds <NICK>  -- blocks downloads ( d ) and search ( s )
 [+!#]trafficmanager block dus <NICK>  -- blocks downloads ( d ), uploads ( u ) and search ( s )
 [+!#]trafficmanager unblock <NICK>  -- unblock user
 [+!#]trafficmanager show settings  -- shows current settings from "cfg/cfg.tbl"
 [+!#]trafficmanager show blocks  -- shows all blockes users and her blockmodes

=========================================================== TRAFFIC MANAGER ===
  ]]

local msg_users = lang.msg_users or [[


=== TRAFFIC MANAGER ================================

               Blockmode              Username
  -------------------------------------------------------------------------------------

%s
  -------------------------------------------------------------------------------------
  ds = download, search  |  dus = download, upload, search

================================ TRAFFIC MANAGER ===
  ]]

--// functions
local block_tbl
local onbmsg
local get_blocklevels
local get_bool
local check_share
local is_blocked
local send_report
local format_description


----------
--[CODE]--
----------

local masterlevel = util_getlowestlevel( permission )

--// get all levelnames from blocked table in sorted order
get_blocklevels = function()
    local levels = cfg_get( "levels" ) or {}
    local tbl = {}
    local i = 1
    local msg = ""
    for k, v in pairs( blocklevel_tbl ) do
        if k >= 0 then
            if v then
                tbl[ i ] = k
                i = i + 1
            end
        end
    end
    table.sort( tbl )
    for _, level in pairs( tbl ) do
        msg = msg .. "\t" .. levels[ level ] .. "\n"
    end
    return msg
end

--// returns value of a bool as string
get_bool = function( var )
    local msg = "false"
    if var then msg = "true" end
    return msg
end

--// check if user has no share
check_share = function( user )
    local user_level = user:level()
    local user_share = user:share()
    local result = false
    if user_level < oplevel then
        if sharecheck then
            if user_share == 0 then
                result = true
            end
        end
    end
    return result
end

--// check if target user is still blocked
is_blocked = function( target )
    if target then
        local target_firstnick = target:firstnick()
        local target_level = target:level()
        for sid, user in pairs( hub_getusers() ) do
            if blocklevel_tbl[ target_level ] or check_share( target ) then
                return true
            else
                for k, v in pairs( block_tbl ) do
                    if k == target_firstnick then
                        return true
                    end
                end
            end
        end
    end
    return false
end

--// report
send_report = function( msg, minlevel )
    if report then
        if report_hubbot then
            for sid, user in pairs( hub_getusers() ) do
                local user_level = user:level()
                if user_level >= minlevel then
                    user:reply( msg, hub_getbot, hub_getbot )
                end
            end
        end
        if report_opchat then
            if opchat_activate then
                opchat.feed( msg )
            end
        end
    end
end

--// add/remove description flag
format_description = function( flag, listener, target, cmd )
    local desc, new_desc = "", ""
    if listener == "onStart" then
        if desc_prefix_activate and desc_prefix_permission[ target:level() ] then
            local desc_tag = hub_escapeto( desc_prefix_table[ target:level() ] )
            local desc = target:description() or ""
            local desc_part1 = desc:sub( 1, #desc_tag )
            local desc_part2 = desc:sub( #desc_tag + 1, #desc )
            local prefix = hub_escapeto( flag )
            new_desc = desc_part1 .. prefix .. desc_part2
        else
            local prefix = hub_escapeto( flag_ds )
            local desc = target:description() or ""
            new_desc = prefix .. desc
        end
    end
    if listener == "onExit" then
        if desc_prefix_activate and desc_prefix_permission[ target:level() ] then
            local prefix = hub_escapeto( flag )
            local desc_tag = hub_escapeto( desc_prefix_table[ target:level() ] )
            local desc = utf_sub( target:description(), utf_len( desc_tag ) + 1, -1 )
            local desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
            new_desc = desc_tag .. desc
        else
            --[[
            local prefix = hub_escapeto( flag )
            local desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
            new_desc = desc
            ]]
            local prefix = hub_escapeto( flag )
            local desc = target:description() or ""
            new_desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
        end
    end
    if listener == "onInf" then
        if desc_prefix_activate and desc_prefix_permission[ target:level() ] then
            local desc_tag = hub_escapeto( desc_prefix_table[ target:level() ] )
            local desc = cmd:getnp "DE"
            local desc_part1 = desc:sub( 1, #desc_tag )
            local desc_part2 = desc:sub( #desc_tag + 1, #desc )
            local prefix = hub_escapeto( flag )
            new_desc = desc_part1 .. prefix .. desc_part2
        else
            local prefix = hub_escapeto( flag )
            local desc = cmd:getnp "DE"
            new_desc = prefix .. desc
        end
    end
    if listener == "onConnect" then
        if desc_prefix_activate and desc_prefix_permission[ target:level() ] then
            local desc_tag = hub_escapeto( desc_prefix_table[ target:level() ] )
            local desc = target:description() or ""
            local desc_part1 = desc:sub( 1, #desc_tag )
            local desc_part2 = desc:sub( #desc_tag + 1, #desc )
            local prefix = hub_escapeto( flag )
            new_desc = desc_part1 .. prefix .. desc_part2
        else
            local prefix = hub_escapeto( flag )
            local desc = target:description() or ""
            new_desc = prefix .. desc
        end
    end
    return new_desc
end

if activate then
    --// if user logs in
    hub.setlistener( "onLogin", {},
        function( user )
            local user_level = user:level()
            local user_firstnick = user:firstnick()
            local msg
            if blocklevel_tbl[ user_level ] then
                if login_report then
                    local levelname = cfg_get( "levels" )[ user_level ] or "Unreg"
                    msg = utf_format( report_msg,
                                      user_firstnick,
                                      user_level,
                                      levelname,
                                      get_bool( block_ctm ),
                                      get_bool( block_rcm ),
                                      get_bool( block_sch )
                    )
                    if report_main then user:reply( msg, hub_getbot ) end
                    if report_pm then user:reply( msg, hub_getbot, hub_getbot ) end
                end
            elseif check_share( user ) then
                if login_report then
                    msg = utf_format( report_msg_2,
                                      user_firstnick,
                                      get_bool( block_ctm ),
                                      get_bool( block_rcm ),
                                      get_bool( block_sch )
                    )
                    if report_main then user:reply( msg, hub_getbot ) end
                    if report_pm then user:reply( msg, hub_getbot, hub_getbot ) end
                end
            else
                if login_report then
                    for k, v in pairs( block_tbl ) do
                        if k == user_firstnick then
                            if v == "ds" then
                                msg = utf_format( report_msg_3,
                                                  user_firstnick,
                                                  "true",
                                                  "false",
                                                  "true"
                                )
                            elseif v == "dus" then
                                msg = utf_format( report_msg_3,
                                                  user_firstnick,
                                                  "true",
                                                  "true",
                                                  "true"
                                )
                            end
                            if report_main then user:reply( msg, hub_getbot ) end
                            if report_pm then user:reply( msg, hub_getbot, hub_getbot ) end
                        end
                    end
                end
            end
            return nil
        end
    )
    --// hubcmd
    onbmsg = function( user, command, parameters )
        local user_nick = user:nick()
        local user_level = user:level()
        local target_firstnick, target_level, target_sid
        local p1, p2 = utf_match( parameters, "^(%S+) (%S+)" )
        local p3, p4,p5 = utf_match( parameters, "^(%S+) (%S+) (%S+)" )
        --// [+!#]trafficmanager show settings
        if ( ( p1 == cmd_s ) and ( p2 == "settings" ) ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local msg = utf_format( opmsg,
                                    get_bool( activate ),
                                    get_bool( block_ctm ),
                                    get_bool( block_rcm ),
                                    get_bool( block_sch ),
                                    get_bool( login_report ),
                                    get_bool( report_main ),
                                    get_bool( report_pm ),
                                    get_blocklevels(),
                                    get_bool( sharecheck )
            )
            user:reply( msg, hub_getbot )
            return PROCESSED
        end
        --// [+!#]trafficmanager show blocks
        if ( ( p1 == cmd_s ) and ( p2 == "blocks" ) ) then
            if user_level < oplevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local msg = ""
            for k, v in pairs( block_tbl ) do
                msg = msg .. "\t" .. v .. "\t\t" .. k .. "\n"
            end
            local msg_out = utf_format( msg_users, msg )
            user:reply( msg_out, hub_getbot )
            return PROCESSED
        end
        if ( ( p3 == cmd_b ) and p4 and p5 ) then
            local target = hub_isnickonline( p5 )
            if target then
                if target:isbot() then
                    user:reply( msg_isbot, hub_getbot )
                    return PROCESSED
                else
                    target_firstnick = target:firstnick()
                    target_level = target:level()
                end
            else
                user:reply( msg_notonline, hub_getbot )
                return PROCESSED
            end
            --// [+!#]trafficmanager block ds <NICK>
            if p4 == "ds" then
                if is_blocked( target ) then
                    user:reply( msg_stillblocked, hub_getbot )
                    return PROCESSED
                else
                    if ( ( permission[ user_level ] or 0 ) < target_level ) then
                        user:reply( msg_god, hub_getbot )
                        return PROCESSED
                    else
                        block_tbl[ target_firstnick ] = "ds"
                        util_savetable( block_tbl, "block_tbl", block_file )
                        local msg = utf_format( msg_block, target_firstnick, "D,S" )
                        user:reply( msg, hub_getbot )
                        local msg_report = utf_format( msg_op_report_block, user_nick, target_firstnick, "D,S" )
                        send_report( msg_report, llevel )
                        --// add description flag
                        for sid, buser in pairs( hub_getusers() ) do
                            if buser:firstnick() == target_firstnick then
                                local new_desc = format_description( flag_ds, "onStart", buser, nil )
                                buser:inf():setnp( "DE", new_desc )
                                hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                            end
                        end
                        return PROCESSED
                    end
                end
            end
            --// [+!#]trafficmanager block dus <NICK>
            if p4 == "dus" then
                if is_blocked( target ) then
                    user:reply( msg_stillblocked, hub_getbot )
                    return PROCESSED
                else
                    if ( ( permission[ user_level ] or 0 ) < target_level ) then
                        user:reply( msg_god, hub_getbot )
                        return PROCESSED
                    else
                        block_tbl = util_loadtable( block_file )
                        block_tbl[ target_firstnick ] = "dus"
                        util_savetable( block_tbl, "block_tbl", block_file )
                        local msg = utf_format( msg_block, target_firstnick, "D,U,S" )
                        user:reply( msg, hub_getbot )
                        local msg_report = utf_format( msg_op_report_block, user_nick, target_firstnick, "D,U,S" )
                        send_report( msg_report, llevel )
                        --// add description flag
                        for sid, buser in pairs( hub_getusers() ) do
                            if buser:firstnick() == target_firstnick then
                                local new_desc = format_description( flag_dus, "onStart", buser, nil )
                                buser:inf():setnp( "DE", new_desc )
                                hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                            end
                        end
                        return PROCESSED
                    end
                end
            end
        end
        --// [+!#]trafficmanager unblock <NICK>
        if ( ( p1 == cmd_u ) and p2 ) then
            if user_level < masterlevel then
                user:reply( msg_denied, hub_getbot )
                return PROCESSED
            end
            local target = hub_isnickonline( p2 )
            if target then
                target_firstnick = target:firstnick()
                target_sid = target:sid()
            else
                target_firstnick = p2
            end
            local found = false
            for k, v in pairs( block_tbl ) do
                if k == target_firstnick then
                    if target then
                        --// remove description flag
                        local new_desc
                        if v == "ds" then
                            if desc_prefix_activate and desc_prefix_permission[ target:level() ] then
                                local prefix = hub_escapeto( flag_ds )
                                local desc_tag = hub_escapeto( desc_prefix_table[ target:level() ] )
                                local desc = utf_sub( target:description(), utf_len( desc_tag ) + 1, -1 )
                                local desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
                                new_desc = desc_tag .. desc
                            else
                                --[[
                                local prefix = hub_escapeto( flag_ds )
                                local desc = utf_sub( desc, utf_len( prefix ) + 1, -1 ) or " "
                                new_desc = desc
                                ]]
                                local prefix = hub_escapeto( flag_ds )
                                local desc = target:description() or ""
                                new_desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
                            end
                        elseif v == "dus" then
                            if desc_prefix_activate and desc_prefix_permission[ target:level() ] then
                                local prefix = hub_escapeto( flag_dus )
                                local desc_tag = hub_escapeto( desc_prefix_table[ target:level() ] )
                                local desc = utf_sub( target:description(), utf_len( desc_tag ) + 1, -1 )
                                local desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
                                new_desc = desc_tag .. desc
                            else
                                --[[
                                local prefix = hub_escapeto( flag_dus )
                                local desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
                                new_desc = desc
                                ]]
                                local prefix = hub_escapeto( flag_dus )
                                local desc = target:description() or ""
                                new_desc = utf_sub( desc, utf_len( prefix ) + 1, -1 )
                            end
                        end
                        target:inf():setnp( "DE", new_desc or "" )
                        hub_sendtoall( "BINF " .. target_sid .. " DE" .. new_desc .. "\n" )
                    end
                    block_tbl[ k ] = nil
                    found = true
                    break
                end
            end
            if found then
                util_savetable( block_tbl, "block_tbl", block_file )
                local msg = utf_format( msg_unblock, target_firstnick )
                user:reply( msg, hub_getbot )
                local msg_report = utf_format( msg_op_report_unblock, user_nick, target_firstnick )
                send_report( msg_report, llevel )
                return PROCESSED
            else
                user:reply( msg_notfound, hub_getbot )
                return PROCESSED
            end
        end
        user:reply( msg_usage, hub_getbot )
        return PROCESSED
    end
    --// block users download
    hub.setlistener( "onConnectToMe", {},
        function( user )
            local user_level = user:level()
            local user_firstnick = user:firstnick()
            if block_ctm then
                if blocklevel_tbl[ user_level ] then
                    return PROCESSED
                elseif check_share( user ) then
                    return PROCESSED
                end
            end
            for k, v in pairs( block_tbl ) do
                if k == user_firstnick then
                    if v == "ds" then
                        return PROCESSED
                    elseif v == "dus" then
                        return PROCESSED
                    end
                end
            end
            return nil
        end
    )
    --// block users upload
    hub.setlistener( "onRevConnectToMe", {},
        function( user )
            local user_level = user:level()
            local user_firstnick = user:firstnick()
            if block_rcm then
                if blocklevel_tbl[ user_level ] then
                    return PROCESSED
                elseif check_share( user ) then
                    return PROCESSED
                end
            end
            for k, v in pairs( block_tbl ) do
                if k == user_firstnick then
                    if v == "ds" then
                        --return PROCESSED
                    elseif v == "dus" then
                        return PROCESSED
                    end
                end
            end
            return nil
        end
    )
    --// block users search
    hub.setlistener( "onSearch", {},
        function( user )
            local user_level = user:level()
            local user_firstnick = user:firstnick()
            if block_sch then
                if blocklevel_tbl[ user_level ] then
                    return PROCESSED
                elseif check_share( user ) then
                    return PROCESSED
                end
            end
            for k, v in pairs( block_tbl ) do
                if k == user_firstnick then
                    if v == "ds" then
                        return PROCESSED
                    elseif v == "dus" then
                        return PROCESSED
                    end
                end
            end
            return nil
        end
    )
    --// script start
    hub.setlistener( "onStart", {},
        function()
            --// help, ucmd, hucmd
            local help = hub_import( "cmd_help" )
            if help then
                help.reg( help_title, help_usage, help_desc, oplevel )
                help.reg( help_title2, help_usage2, help_desc2, masterlevel )
            end
            local ucmd = hub_import( "etc_usercommands" )
            if ucmd then
                ucmd.add( ucmd_menu_ct1_1, cmd, { cmd_s, "settings" }, { "CT1" }, oplevel )
                ucmd.add( ucmd_menu_ct1_2, cmd, { cmd_s, "blocks" }, { "CT1" }, oplevel )
                ucmd.add( ucmd_menu_ct2_1, cmd, { cmd_b, "ds", "%[userNI]" }, { "CT2" }, masterlevel )
                ucmd.add( ucmd_menu_ct2_2, cmd, { cmd_b, "dus", "%[userNI]" }, { "CT2" }, masterlevel )
                ucmd.add( ucmd_menu_ct2_3, cmd, { cmd_u, "%[userNI]" }, { "CT2" }, masterlevel )
            end
            local hubcmd = hub_import( "etc_hubcommands" )
            assert( hubcmd )
            assert( hubcmd.add( cmd, onbmsg ) )
            --// add description flag
            block_tbl = util_loadtable( block_file )
            for sid, user in pairs( hub_getusers() ) do
                if blocklevel_tbl[ user:level() ] or check_share( user ) then
                    local new_desc = format_description( flag_lvl, "onStart", user, nil )
                    user:inf():setnp( "DE", new_desc )
                    hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                else
                    for k, v in pairs( block_tbl ) do
                        if k == user:firstnick() then
                            if v == "ds" then
                                local new_desc = format_description( flag_ds, "onStart", user, nil )
                                user:inf():setnp( "DE", new_desc )
                                hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                            elseif v == "dus" then
                                local new_desc = format_description( flag_dus, "onStart", user, nil )
                                user:inf():setnp( "DE", new_desc )
                                hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                            end
                        end
                    end
                end
            end
            return nil
        end
    )
    --// script exit
    hub.setlistener( "onExit", {},
        function()
            --// remove description flag
            for sid, user in pairs( hub_getusers() ) do
                if blocklevel_tbl[ user:level() ] or check_share( user ) then
                    local new_desc = format_description( flag_lvl, "onExit", user, nil )
                    user:inf():setnp( "DE", new_desc or "" )
                    hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                else
                    for k, v in pairs( block_tbl ) do
                        if k == user:firstnick() then
                            if v == "ds" then
                                local new_desc = format_description( flag_ds, "onExit", user, nil )
                                user:inf():setnp( "DE", new_desc or "" )
                                hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                            elseif v == "dus" then
                                local new_desc = format_description( flag_dus, "onExit", user, nil )
                                user:inf():setnp( "DE", new_desc or "" )
                                hub_sendtoall( "BINF " .. sid .. " DE" .. new_desc .. "\n" )
                            end
                        end
                    end
                end
            end
            return nil
        end
    )
    --// incoming INF
    hub.setlistener( "onInf", {},
        function( user, cmd )
            local desc = cmd:getnp "DE"
            if desc then
                --// add/update description flag
                if blocklevel_tbl[ user:level() ] or check_share( user ) then
                    local new_desc = format_description( flag_lvl, "onInf", user, cmd )
                    cmd:setnp( "DE", new_desc )
                    user:inf():setnp( "DE", new_desc )
                else
                    for k, v in pairs( block_tbl ) do
                        if k == user:firstnick() then
                            if v == "ds" then
                                local new_desc = format_description( flag_ds, "onInf", user, cmd )
                                cmd:setnp( "DE", new_desc )
                                user:inf():setnp( "DE", new_desc )
                            elseif v == "dus" then
                                local new_desc = format_description( flag_dus, "onInf", user, cmd )
                                cmd:setnp( "DE", new_desc )
                                user:inf():setnp( "DE", new_desc )
                            end
                        end
                    end
                end
            end
            return nil
        end
    )
    --// user connects to hub
    hub.setlistener( "onConnect", {},
        function( user )
            --// add description flag
            if blocklevel_tbl[ user:level() ] or check_share( user ) then
                local new_desc = format_description( flag_lvl, "onConnect", user, nil )
                user:inf():setnp( "DE", new_desc )
            else
                for k, v in pairs( block_tbl ) do
                    if k == user:firstnick() then
                        if v == "ds" then
                            local new_desc = format_description( flag_ds, "onConnect", user, nil )
                            user:inf():setnp( "DE", new_desc )
                        elseif v == "dus" then
                            local new_desc = format_description( flag_dus, "onConnect", user, nil )
                            user:inf():setnp( "DE", new_desc )
                        end
                    end
                end
            end
            return nil
        end
    )
end

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )