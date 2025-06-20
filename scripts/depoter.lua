---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local shared = require('TSC.scripts.shared')
local me = mq.TLO.Me.Name()

--Load data
local lists = cm.loadData('lists')

local function binds()
    shared.tryAgain = true
end
mq.bind('/tsresume', binds)

if mq.TLO.TradeskillDepot.Enabled() and (lists.todepot[me] or lists.tomovedepot[me]) then
    print('\at[TsC]\ao Putting items in the depot...')
    if lists.todepot[me] then
        shared.putInDepot(lists.todepot[me], false)
    end
    if lists.tomovedepot[me] then
        shared.putInDepot(lists.tomovedepot[me], false)
    end
end

shared.execute(cm.settings.driver, '/tsc donedepot')

mq.unbind('/tsresume')