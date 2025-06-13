--- @type Mq
local mq = require('mq')
local utils = require('TSC.utils')
local cm = require('TSC.configmanager')
local sm = require('TSC.statemanager')
local im = require('TSC.itemmanager')

local binds = {}

function binds.commands(a, b, c, d)
    if a == 'donescanning' then
        utils.waitingcounter = utils.waitingcounter + 1
        if sm.stats[b]['beforeItems'] == 'unset' then
            sm.stats[b]['beforeItems'] = c
            sm.stats[b]['beforeSlots'] = d
        else
            sm.stats[b]['afterItems'] = c
            sm.stats[b]['afterSlots'] = d
        end
    elseif a == 'donegrabbing' or a == 'donetrading' or a == 'donedepot' or a == 'donerest' or a == 'donebanking' then
        utils.waitingcounter = utils.waitingcounter + 1
    elseif a == 'beentoplots' then
        im.lists.tomoveplot[b] = nil
        cm.saveData('lists', im.lists)
    end
end

return binds