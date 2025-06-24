--- @type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local tm = require('TSC.toonmanager')
local sm = require('TSC.statemanager')

---@class Utilities
local utils = {}

local me = mq.TLO.Me.Name()


--
--General
--

function utils.fname(name)
    return name
end


--Cleanup and exit (or restart) the script
function utils.stopAll(restart)

    for toon,_ in pairs(cm.toons) do
        mq.cmdf('/dobserve %s -drop Me.FreeInventory', toon)
        utils.execute(toon, '/squelch /lua stop tsc/scripts/banker')
        utils.execute(toon, '/squelch /lua stop tsc/scripts/depoter')
        utils.execute(toon, '/squelch /lua stop tsc/scripts/grabber')
        utils.execute(toon, '/squelch /lua stop tsc/scripts/leftover')
        utils.execute(toon, '/squelch /lua stop tsc/scripts/scanner')
        utils.execute(toon, '/squelch /lua stop tsc/scripts/trader')
        utils.execute(toon, '/squelch /nav stop')
    end
    for mule,_ in pairs(cm.mules) do
        mq.cmdf('/dobserve %s -drop Me.FreeInventory', mule)
    end
    if restart == true then
        mq.cmd('/lua run TSC/restart')
    end
    mq.unbind('/tsc')
    mq.exit()
end

--Return the length of a table
function utils.tableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end


--
--Common user commands
--


--Check if the cursor is empty and if so, run autoinv
function utils.autoinv()
    while mq.TLO.Cursor() do
        mq.cmd('/autoinv')
        mq.delay(200)
    end
end

--Close all windows
function utils.cleanup()
    mq.cmd('/cleanup')
end


--
--GUI related
--


--Flip imgui checkboxes
function utils.switch(v)
    v = not v
end

--Alphabetize keep and ignore list tables
function utils.getSortedKeys(mytable)
    local keys = {}
    for k in pairs(mytable) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        for n = 1, current_sort_specs.SpecsCount, 1 do
            local sort_spec = current_sort_specs:Specs(n)
            local delta = 0
            if a == nil or b == nil then return end
            a = a:lower()
            b = b:lower()
            if a < b then
                delta = -1
            elseif b < a then
                delta = 1
            else
                delta = 0
            end
            if delta ~= 0 then
                if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                    return delta < 0
                end
                return delta > 0
            end
        end
        return a < b
    end)
    return keys
end

-- Convert a table formatted as ['name'] = true into an alphabetized indexed table
function utils.getAlphabetizedList(mytable)
    local list = {}
    for name, _ in pairs(mytable) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

--Alphabetically sort search list table
function utils.sortSearch(a, b)
    a = a['item']
    b = b['item']
    for n = 1, current_sort_specs.SpecsCount, 1 do
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0
        if a == nil or b == nil then return end
        a = a:lower()
        b = b:lower()
        if a < b then
            delta = -1
        elseif b < a then
            delta = 1
        else
            delta = 0
        end
        if delta ~= 0 then
            if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            end
            return delta > 0
        end
    end
    return a < b
end


--
--Routine helpers
--


--Make sure banker is in zone
function utils.checkBanker()
    if mq.TLO.NearestSpawn('banker').Name() == nil then
        print('\at[TsC]\ao There is no banker in this zone. Stopping.')
        return false
    end
    return true
end

--Continue monitoring toons while waiting everyone's scripts to finish
utils.waitingcounter = 0
function utils.waiting(length)
    while utils.waitingcounter < length do
        tm:runPeriodicTasks()
    end
    utils.waitingcounter = 0
end

--Continue monitoring toons while waiting for user input
function utils.waitingUser()
    while sm.tradeConfirmWnd or sm.leftoverConfirmWnd or sm.status == 'Depot warning' do
        tm:runPeriodicTasks()
    end
end

--Handles mq.cmd(f) for the current toon or other toons, deciding to use /dex or not
function utils.execute(who, command)
    --Only if the command contains a variable
    if string.find(command, '%${') then
        if who == me then
            mq.cmdf('/docommand %s', command)
        else
            mq.cmdf('/noparse /dex %s /docommand %s', who, command)
        end
    --If the command does not contain a variable, we can use /dex to send it to other toons
    else
        if who == me then
            mq.cmdf(command)
        else
            mq.cmdf('/dex %s %s', who, command)
        end
    end
end

function utils.clearStats()
    for toon in pairs(tm.onlineToons) do
        sm.stats[toon] = {}
        sm.stats[toon]['beforeItems'] = 'unset'
        sm.stats[toon]['beforeSlots'] = 'unset'
        sm.stats[toon]['afterItems'] = 'unset'
        sm.stats[toon]['afterSlots'] = 'unset'
    end
end

--Pause toons if they are running a macro or plugin
local pausedToons = {}
function utils.pauseToons(toonTable)
    pausedToons = {} -- Reset the list of paused toons

    -- Check and pause other toons if necessary
    for toon, _ in pairs(toonTable) do
        if toon ~= me then
            -- Send queries to check if the toon is running a macro or plugin
            mq.cmdf('/dquery %s -q Macro', toon) mq.delay(100)
            mq.cmdf('/dquery %s -q CWTN', toon) mq.delay(100)
            mq.cmdf('/dquery %s -q Macro.Paused', toon) mq.delay(100)
            mq.cmdf('/dquery %s -q CWTN.Paused', toon) mq.delay(100)

            -- Add a delay to allow the queries to process
            mq.delay(100)

            local macroRunning = mq.TLO.DanNet(toon).Q('Macro')() ~= 'NULL'
            local pluginRunning = mq.TLO.DanNet(toon).Q('CWTN')() == 'CWTN'
            local macroPaused = macroRunning and mq.TLO.DanNet(toon).Q('Macro.Paused')() == 'TRUE'
            local pluginPaused = pluginRunning and mq.TLO.DanNet(toon).Q('CWTN.Paused')() == 'TRUE'

            if macroRunning and not macroPaused then
                mq.cmdf('/dex %s /mqp on', toon)
                table.insert(pausedToons, toon)
            end
            if pluginRunning and not pluginPaused then
                mq.cmdf('/noparse /dex %s /docommand /${Me.Class.ShortName} pause on', toon)
                table.insert(pausedToons, toon)
            end
        else
            -- Check and pause the main toon if necessary
            local mainMacroRunning = mq.TLO.Macro() ~= nil
            local mainPluginRunning = mq.TLO.CWTN ~= nil
            local mainMacroPaused = mainMacroRunning and mq.TLO.Macro.Paused()
            local mainPluginPaused = mainPluginRunning and mq.TLO.CWTN.Paused()

            if mainMacroRunning and not mainMacroPaused then
                mq.cmd('/mqp on')
                table.insert(pausedToons, me)
            end
            if mainPluginRunning and not mainPluginPaused then
                mq.cmd('/docommand /${Me.Class.ShortName} pause on')
                table.insert(pausedToons, me)
            end
        end
    end
end

--Unpause toons that were previously paused
function utils.unpauseToons()
    for _, toon in ipairs(pausedToons) do
        if toon == me then
            if mq.TLO.Macro() ~= nil then
                mq.cmd('/mqp off')
            end
            if mq.TLO.CWTN ~= nil then
                mq.cmd('/docommand /${Me.Class.ShortName} pause off')
            end
        else
            if mq.TLO.DanNet(toon).Q('Macro')() ~= 'NULL' then
                mq.cmdf('/dex %s /mqp off', toon)
            end
            if mq.TLO.DanNet(toon).Q('CWTN')() ~= nil then
                mq.cmdf('/noparse /dex %s /docommand /${Me.Class.ShortName} pause off', toon)
            end
        end
    end
    pausedToons = {} -- Clear the list of paused toons
end

return utils