--- @type Mq
local mq = require('mq')
local utils = require('utils')
local home = require('plot')

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local movePath = 'TSC/tmp/movetable.lua'

local settings = {}
local moveTable = {}

local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local movefile, moveerror = loadfile(mq.configDir..'/'..movePath)
    if moveerror then
        print('Error loading movetable.lua')
        mq.exit()
    elseif movefile then
        moveTable = movefile()
    end
end
loadfiles()

print('\at[TsC]\ao Looking for items to move to bank...')
mq.delay(1000)

local bankList = moveTable[me]['tobank']

local count = 0

count = count + utils.bank(bankList)

if settings.preferPlots == true then
    print('\at[TsC]\ao Looking for items to move to plot...')
    mq.delay(1000)
    local plotList = moveTable[me]['toplot']
    if utils.listSize(plotList) > 0 then
        local currentPlot
        
        for plots, items in pairs(moveTable[me]['toplot']) do
            local neigh, plot, room = string.match(plots, "([^,]+),%s*([^,]+),%s*([^,]+)")
            local uniquePlot = neigh..", "..plot
            if currentPlot ~= uniquePlot then
                currentPlot = uniquePlot
                print('\at[TsC]\ao Heading to \ay'..plots..'\ao.')
                home.go(neigh, plots)
                utils.cleanup()
                mq.delay(1000)
            end
            --utils.putInPlot(items, room)
        end

    end
end

if count > 0 then
    mq.cmdf('/dt %s \awDone banking. Banked \ay%s \awunique items.', settings.driver, count)
end

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donebanking')
else
    mq.cmdf('/dex %s /tsc donebanking', settings.driver)
end