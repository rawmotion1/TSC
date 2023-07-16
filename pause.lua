--- @type Mq
local mq = require('mq')

local args = {...}
local state = args[1]
local type = args[2]
local me = mq.TLO.Me.Name()

local settingPath = 'TSC/settings.lua'
local settings = {}
local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
if setError then
    print('\at[TsC]\ao Error loading settings.lua')
    mq.exit()
elseif loadSettings then
    settings = loadSettings()
end

if state == 'on' then
    if mq.TLO.Macro() then
        if mq.TLO.Macro.Paused() == false then
            mq.cmd('/mqp on')
            if settings.driver == me then
                mq.cmdf('/tsc pausedmacro %s', me)
            else
                mq.cmdf('/dex %s /tsc pausedmacro %s', settings.driver, me)
            end
        end
    end
    if mq.TLO.CWTN then
        if mq.TLO.CWTN.Paused() == false then
            local short = mq.TLO.Me.Class.ShortName()
            mq.cmdf('/%s pause on', short)
            if settings.driver == me then
                mq.cmdf('/tsc pausedplugin %s', me)
            else
                mq.cmdf('/dex %s /tsc pausedplugin %s', settings.driver, me)
            end
        end
    end
elseif state == 'off' then
    if type == 'macro' then
        mq.cmd('/mqp off')
    elseif type == 'plugin' then
        local short = mq.TLO.Me.Class.ShortName()
        mq.cmdf('/%s pause off', short)
    elseif type == 'both' then
        mq.cmd('/mqp off')
        local short = mq.TLO.Me.Class.ShortName()
        mq.cmdf('/%s pause off', short)
    end
end