---@type Mq
local mq = require('mq')

local plots = {}

function plots.go(neigh, plot)

    if mq.TLO.Zone.ShortName() ~= 'guildlobby' and mq.TLO.Zone.ShortName() ~= 'neighborhood' then
        mq.cmd('/travelto guildlobby')

        while mq.TLO.Zone.ShortName() ~= 'guildlobby' do
            mq.delay(500)
        end
    end

    if mq.TLO.Zone.ShortName() == 'guildlobby' then

        mq.cmd('/nav loc 969 293 -18')
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

        mq.delay(1000)

        local listSize = mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_NeighborhoodList').Items()

        for i=1, listSize do
            local location = mq.TLO.Window('RealEstateNeighborHoodWnd').Child('RENW_NeighborhoodList').List(i,1)()
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

        mq.cmd('/nav loc -2779 1943 5')
        while mq.TLO.Navigation.Active() do
            mq.delay(1000)
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

        local myPlot = mq.TLO.Switch('Nearest')()

        mq.cmdf('/nav door id %s', myPlot)

        while mq.TLO.Navigation.Active() do
            if mq.TLO.Switch('Nearest').Distance() < 30 then
                mq.cmd('/nav stop')
                break
            end
            mq.delay(10)
        end

        mq.delay(1000)

    end
end

return plots