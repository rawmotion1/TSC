---@type Mq
local mq = require('mq')
local returnZone = {}

function returnZone.go(startZone)
    local stuck = false
    local tryAgain = false
    
    local function returnToStart()
        mq.cmdf('/travelto %s', startZone)
        print('\at[TsC]\ao Returning to \ay'..startZone..'\ao.')

        local startx, starty, endx, endy, diffx, diffy
        while mq.TLO.Navigation.Active() and mq.TLO.Zone.ShortName() == 'neighborhood' do
            startx, starty = mq.TLO.Me.X(), mq.TLO.Me.Y()
            mq.delay(5000)
            endx, endy = mq.TLO.Me.X(), mq.TLO.Me.Y()
            diffx, diffy = math.abs(endx - startx), math.abs(endy - starty)
            if diffx < 5 and diffy < 5 then
                stuck = true
            end
            while stuck == true do
                local function stop() return tryAgain end
                mq.cmdf('/dgt \at[TsC] \ag:::ALERT::: \ar %s \ayis probably stuck on a wall in Sunrise Hills.', mq.TLO.Me.Name())
                mq.cmdf('/dgt \at[TsC] \ag:::ALERT:::\ay Get them unstuck, then type \ag/tsresume\ay from their EQ window.')
                mq.delay(10000, stop)
            end
        end
    end

    local function binds()
        tryAgain = true
        stuck = false
        returnToStart()
    end
    mq.bind('/tsresume', binds)

    returnToStart()

    while mq.TLO.Zone.ShortName() ~= startZone do
        mq.delay(500)
    end
    mq.unbind('/tsresume')
end

return returnZone