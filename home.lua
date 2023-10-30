---@type Mq
local mq = require('mq')
local home = {}
local loc = require('plotlocations')


function home.go(neigh, plot)
    if mq.TLO.Zone.ShortName() ~= 'guildlobby' and mq.TLO.Zone.ShortName() ~= 'neighborhood' then
        mq.cmd('/travelto guildlobby')
        while mq.TLO.Zone.ShortName() ~= 'guildlobby' do
            mq.delay(500)
        end
    end
    if mq.TLO.Zone.ShortName() == 'guildlobby' then
        --Run to gate, select neghborhood, and zone in
        mq.cmd('/squelch /nav loc 969 293 -18')
        while mq.TLO.Navigation.Active() do
            mq.delay(1000)
        end
        while not mq.TLO.Window('RealEstateNeighborHoodWnd').Open() do
            mq.cmd('/doortarget id 38')
            mq.delay(100)
            mq.cmd('/click left door')
            mq.delay(1000)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowNonGuild_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowNonGuild_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowGuild_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowGuild_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowFullPPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowFullPPlots_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowOpenPPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowOpenPPlots_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowFullGPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowFullGPlots_Btn leftmouseup')
            mq.delay(300)
        end
        if not mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_ShowOpenGPlots_Btn').Checked() then
            mq.cmd('/notify RealEstateNeighborHoodWnd RENW_ShowOpenGPlots_Btn leftmouseup')
            mq.delay(300)
        end
        mq.cmd('/notify RealEstateNeighborHoodWnd RENW_MyPlots_Button leftmouseup')
        mq.delay(3000)
        local listSize = mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_NeighborhoodList').Items()
        for i=1, listSize do
            local location = mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_NeighborhoodList').List(i,1)()
            mq.delay(300)
            if string.match(location, neigh) then
                mq.cmdf('/notify RealEstateNeighborHoodWnd RENW_NeighborhoodList listselect %s', i)
                break
            end
        end
        mq.delay(500)
        mq.cmd('/notify RealEstateNeighborHoodWnd RENW_Go_Button leftmouseup')
        while mq.TLO.Zone.ShortName() ~= 'neighborhood' do
            mq.delay(500)
        end
    end


    if mq.TLO.Zone.ShortName() == 'neighborhood' then

        local stuck = false
        local tryAgain = false
        local state

        ----------Nav to spring, select plot, and jump there
        local function navToSpring()
            state = 'spring'
            mq.cmd('/squelch /nav locxy 1943 -2779')
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

            while not mq.TLO.Window('RealEstatePlotSearchWnd').Open() do
                mq.cmd('/doortarget id 132')
                mq.delay(500)
                mq.cmd('/click left door')
                mq.delay(1000)
            end
            if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowPlayer_Btn').Checked() then
                mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowPlayer_Btn leftmouseup')
                mq.delay(300)
            end
            if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowGuild_Btn').Checked() then
                mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowGuild_Btn leftmouseup')
                mq.delay(300)
            end
            if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowOwned_Btn').Checked() then
                mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowOwned_Btn leftmouseup')
                mq.delay(300)
            end
            if not mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_ShowVacant_Btn').Checked() then
                mq.cmd('/notify RealEstatePlotSearchWnd REPSW_ShowVacant_Btn leftmouseup')
                mq.delay(300)
            end
            local listSize = mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_PlotList').Items()
            for i=1, listSize do
                local location = mq.TLO.Window('RealEstatePlotSearchWnd').Child('REPSW_PlotList').List(i,2)()
                if string.match(location, plot) then
                    mq.cmdf('/notify RealEstatePlotSearchWnd REPSW_PlotList listselect %s', i)
                    break
                end
            end
            mq.delay(500)
            mq.cmd('/notify RealEstatePlotSearchWnd REPSW_Go_Btn leftmouseup')
            mq.delay(1000)
            while mq.TLO.Me.Moving() do
                mq.delay(1000)
            end
        end

        local myPlot = loc[plot]

        -----------Nav to plot's switch
        local function navToPlot()
            state = 'plot'
            mq.cmdf('/squelch /nav locxy %s', myPlot)
            local startx, starty, endx, endy, diffx, diffy
            while mq.TLO.Navigation.Active() do
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
            if state == 'spring' then
                navToSpring()
            else
                navToPlot()
            end
        end
        mq.bind('/tsresume', binds)

        --Figure out which is closer: other plot, or spring
        local x,y = string.match(myPlot, '([^,]+),%s([^,]+)')
        tonumber(x)
        tonumber(y)
        local myX, myY = mq.TLO.Me.X(), mq.TLO.Me.Y()
        local disToSpringX, disToSpringY = math.abs(myX - 1943), math.abs(myY + 2779)
        local disToSpring = disToSpringX + disToSpringY
        local disToPlotX, disToPlotY = math.abs(myX - x), math.abs(myY - y)
        local disToPlot = disToPlotX + disToPlotY

        if disToPlot > disToSpring then
            navToSpring()
        end

        navToPlot()


        --Make sure I am standing IN the plot
        local square = {
            [1] = {
                ['x'] = x + 10,
                ['y'] = y
            },
            [2] = {
                ['x'] = x - 10,
                ['y'] = y
            },
            [3] = {
                ['x'] = x,
                ['y'] = y  - 10
            },
            [4] = {
                ['x'] = x,
                ['y'] = y  + 10
            },
        }
        if not mq.TLO.Window('RealEstatePurchaseWnd').Open() then
            mq.TLO.Window('RealEstatePurchaseWnd').DoOpen()
        end
        mq.delay(3000)
        if not mq.TLO.Window('RealEstatePurchaseWnd').Child('REPW_Manage_Button').Enabled() then
            for _,pair in pairs(square) do
                mq.cmdf('/squelch /nav locxy %s %s', pair['x'], pair['y'])
                mq.delay(3000)
                if mq.TLO.Window('RealEstatePurchaseWnd').Child('REPW_Manage_Button').Enabled() then break end
            end
        end

        mq.delay(1000)
        mq.cmd('/cleanup')
        mq.unbind('/tsresume')
    end
end

return home