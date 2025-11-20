--Tradeskill Consolidator (TSC) by raw
--Version 4.1.1
--Last updated: 2025-11-20

---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local tm = require('TSC.toonmanager')
local sm = require('TSC.statemanager')
local routines = require('TSC.routines')
local binds = require('TSC.binds')

mq.cmd('/dgae /dnet fullnames off')

if cm.settings.artisan then
    local upgrade = require('TSC.upgrade')
    local utils = require('TSC.utils')
    print("cm.settings.artisan:", cm.settings.artisan)
    upgrade.run()
    utils.stopAll(true)
end

mq.bind('/tsc', binds.commands)

local main = require('TSC.gui.main')
mq.imgui.init('TSC', main.initGui)
main.openGUI, main.drawGui = true, true

--Check settings, create subtables, and set observers
cm:checkSettings()
tm.createSubtables()
tm.setObservers()

print('\at[TsC]\ao Starting Tradeskill Consolidator v'..cm.version)

while main.openGUI do
    tm:runPeriodicTasks()
    if sm.start == true then
        sm.start = false
        routines:start()
    end
    mq.delay(1000)
end