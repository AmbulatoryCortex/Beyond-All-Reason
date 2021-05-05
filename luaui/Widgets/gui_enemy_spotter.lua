function widget:GetInfo()
	return {
		name = "EnemySpotter",
		desc = "Draws transparant smoothed donuts under enemy units (with teamcolors or predefined colors, depending on situation)",
		author = "Floris (original enemyspotter by TradeMark, who edited 'TeamPlatter' by Dave Rodgers)",
		date = "18 february 2015",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = false
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local renderAllTeamsAsSpec = false        -- renders for all teams when spectator
local renderAllTeamsAsPlayer = false        -- keep this 'false' if you dont want circles rendered under your own units as player

local spotterOpacity = 0.16

local defaultColorsForAllyTeams = 0        -- (number of teams)   if number <= of total numebr of allyTeams then dont use teamcoloring but default colors
local keepTeamColorsForSmallAllyTeam = 99            -- (number of teams)   use teamcolors if number or teams (inside allyTeam)  <=  this value
local spotterColor = {                                -- default color values
	{ 0, 0, 1 }, { 1, 0, 1 }, { 0, 1, 1 }, { 0, 1, 0 }, { 1, 0.5, 0 }, { 0, 1, 1 }, { 1, 1, 0 }, { 1, 1, 1 }, { 0.5, 0.5, 0.5 }, { 0, 0, 0 }, { 0.5, 0, 0 }, { 0, 0.5, 0 }, { 0, 0, 0.5 }, { 0.5, 0.5, 0 }, { 0.5, 0, 0.5 }, { 0, 0.5, 0.5 }, { 1, 0.5, 0.5 }, { 0.5, 0.5, 0.1 }, { 0.5, 0.1, 0.5 },
}

local spotterImg = ":n:LuaUI/Images/enemyspotter.dds"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glDrawListAtUnit = gl.DrawListAtUnit
local glColor = gl.Color
local spGetUnitDefID = Spring.GetUnitDefID
local spGetAllyTeamList = Spring.GetAllyTeamList
local spIsGUIHidden = Spring.IsGUIHidden
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetCameraPosition = Spring.GetCameraPosition
local spGetGameFrame = Spring.GetGameFrame

local myAllyID = Spring.GetMyAllyTeamID()
local gaiaTeamID = Spring.GetGaiaTeamID()

local allyColors = {}
local allyToSpotterColor = {}
local unitConf = {}
local skipOwnAllyTeam = true
local lastUpdatedFrame = 0
local drawUnits = {}

local visibleUnits = {}
local visibleUnitsCount = 0

local prevCam = {}
prevCam[1], prevCam[2], prevCam[3] = spGetCameraPosition()

local chobbyInterface, DrawSpotterList

local ignoreUnits = {}
for udefID, def in ipairs(UnitDefs) do
	if def.customParams['nohealthbars'] then
		ignoreUnits[udefID] = true
	end
end

local numAllyTeams = #Spring.GetAllyTeamList() - 1
local singleTeams = false
if #Spring.GetTeamList() - 1 == numAllyTeams then
	singleTeams = true
end

local sameTeamColors = false
if WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
	sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
end

function setColors()

	if Spring.GetSpectatingState() and renderAllTeamsAsSpec then
		skipOwnAllyTeam = false
	elseif not Spring.GetSpectatingState() and renderAllTeamsAsPlayer then
		skipOwnAllyTeam = false
	end

	local allyToSpotterColorCount = 0
	local allyTeamList = spGetAllyTeamList()
	local numberOfAllyTeams = #allyTeamList
	for _, allyID in pairs(allyTeamList) do

		if not skipOwnAllyTeam or (skipOwnAllyTeam and not (allyID == myAllyID)) then

			allyToSpotterColorCount = allyToSpotterColorCount + 1
			allyToSpotterColor[allyID] = allyToSpotterColorCount
			local usedSpotterColor = spotterColor[allyToSpotterColorCount]
			local teamList = Spring.GetTeamList(allyID)
			if defaultColorsForAllyTeams < numberOfAllyTeams - 1 then
				for teamListIndex = 1, #teamList do
					local teamID = teamList[teamListIndex]
					if teamID ~= gaiaTeamID then
						local pickTeamColor = false
						if (teamListIndex == 1 and #teamList <= keepTeamColorsForSmallAllyTeam) or sameTeamColors then
							-- only check for the first allyTeam, (to be consistent with picking a teamcolor or default color, inconsistency could happen with different teamsizes)
							pickTeamColor = true
						end
						if pickTeamColor then
							-- pick the first team in the allyTeam and take the color from that one
							if teamListIndex == 1 then
								--usedSpotterColor[1],usedSpotterColor[2],usedSpotterColor[3] = Spring.GetTeamColor(teamID)
								local luaAI = Spring.GetTeamLuaAI(teamID)
								if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
									usedSpotterColor[1] = 0.38
									usedSpotterColor[2] = 0.14
									usedSpotterColor[3] = 0.38
								else
									usedSpotterColor[1] = 1
									usedSpotterColor[2] = 0
									usedSpotterColor[3] = 0
								end
							end
						end
					end
				end
			end
			for teamListIndex = 1, #teamList do
				if teamList[teamListIndex] ~= gaiaTeamID then
					allyColors[allyID] = usedSpotterColor
					allyColors[allyID][4] = spotterOpacity
				end
			end
		end
	end

end

function SetUnitConf()
	-- preferred to keep these values the same as fancy unit selections widget
	local scaleFactor = 2.6
	local rectangleFactor = 3.25

	for udid, unitDef in pairs(UnitDefs) do
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = scaleFactor * (xsize ^ 2 + zsize ^ 2) ^ 0.5
		local xscale, zscale

		if unitDef.isBuilding or unitDef.isFactory or unitDef.speed == 0 then
			xscale, zscale = rectangleFactor * xsize, rectangleFactor * zsize
		elseif unitDef.modCategories["ship"] then
			xscale, zscale = scale * 0.82, scale * 0.82
		elseif unitDef.isAirUnit then
			xscale, zscale = scale * 1.07, scale * 1.07
		else
			xscale, zscale = scale, scale
		end

		local radius = Spring.GetUnitDefDimensions(udid).radius
		xscale = (xscale * 0.7) + (radius / 5)
		zscale = (zscale * 0.7) + (radius / 5)

		unitConf[udid] = (xscale + zscale) * 1.5
	end
end

function checkAllUnits()
	drawUnits = {}
	visibleUnits = spGetVisibleUnits(skipOwnAllyTeam and Spring.ENEMY_UNITS or Spring.ALL_UNITS, nil, false)
	visibleUnitsCount = #visibleUnits
	for i = 1, visibleUnitsCount do
		checkUnit(visibleUnits[i])
	end
end

function checkUnit(unitID)
	local allyID = spGetUnitAllyTeam(unitID)
	if not skipOwnAllyTeam or (skipOwnAllyTeam and not (allyID == myAllyID)) then
		local unitDefID = spGetUnitDefID(unitID)
		if ignoreUnits[unitDefID] ~= nil then
			return
		end
		if unitDefID then
			if drawUnits[allyID] == nil then
				drawUnits[allyID] = {}
			end
			drawUnits[allyID][unitID] = unitConf[unitDefID]
		end
	end
end

--------------------------------------------------------------------------------
-- Engine Calls
--------------------------------------------------------------------------------

function widget:Initialize()

	WG['enemyspotter'] = {}
	WG['enemyspotter'].getOpacity = function()
		return spotterOpacity
	end
	WG['enemyspotter'].setOpacity = function(value)
		spotterOpacity = value
		setColors()
	end

	SetUnitConf()
	setColors()
	checkAllUnits()
	DrawSpotterList = gl.CreateList(function()
		gl.TexRect(-1, 1, 1, -1)
	end)
end

function widget:Shutdown()
	WG['enemyspotter'] = nil
	if DrawSpotterList ~= nil then
		gl.DeleteList(DrawSpotterList)
	end
end

function widget:DrawWorldPreUnit()
	if singleTeams or (sameTeamColors and numAllyTeams <= 2) then
		return
	end
	if chobbyInterface then
		return
	end
	if spIsGUIHidden() then
		return
	end

	gl.DepthTest(true)
	gl.PolygonOffset(-100, -2)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)      -- disable layer blending
	gl.Texture(spotterImg)

	for _, allyID in ipairs(spGetAllyTeamList()) do
		if allyColors[allyID] ~= nil and drawUnits[allyID] ~= nil then
			glColor(allyColors[allyID])
			for unitID, unitScale in pairs(drawUnits[allyID]) do
				glDrawListAtUnit(unitID, DrawSpotterList, false, unitScale, unitScale, unitScale, 90, 1, 0, 0)
			end
		end
	end

	gl.Texture(false)
	glColor(1, 1, 1, 1)
	gl.PolygonOffset(false)
end

local sec = 0
local sceduledCheck = false
local updateTime = 1
function widget:Update(dt)
	if chobbyInterface then
		return
	end
	sec = sec + dt
	local camX, camY, camZ = spGetCameraPosition()
	if camX ~= prevCam[1] or camY ~= prevCam[2] or camZ ~= prevCam[3] then
		sceduledCheck = true
	end
	if sec > 1 / updateTime and lastUpdatedFrame ~= spGetGameFrame() or (sec > 1 / (updateTime * 5) and sceduledCheck) then
		sec = 0
		if not singleTeams and WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors then
			if WG['playercolorpalette'].getSameTeamColors() ~= sameTeamColors then
				sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
				setColors()
			end

		end
		lastUpdatedFrame = spGetGameFrame()
		sceduledCheck = false
		updateTime = Spring.GetFPS() / 15
		if updateTime < 0.66 then
			updateTime = 0.66
		end
		--if singleTeams or (sameTeamColors and numAllyTeams <= 2) then return end
		checkAllUnits()
	end
	prevCam[1], prevCam[2], prevCam[3] = camX, camY, camZ
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:PlayerChanged()
	if Spring.GetSpectatingState() and renderAllTeamsAsSpec then
		skipOwnAllyTeam = false
		setColors()
	elseif not Spring.GetSpectatingState() and renderAllTeamsAsPlayer then
		skipOwnAllyTeam = false
		setColors()
	end
end

function widget:GetConfigData(data)
	return {
		renderAllTeamsAsSpec = renderAllTeamsAsSpec,
		renderAllTeamsAsPlayer = renderAllTeamsAsPlayer,
		spotterOpacity = spotterOpacity,
	}
end

function widget:SetConfigData(data)
	if data.renderAllTeamsAsSpec ~= nil then
		renderAllTeamsAsSpec = data.renderAllTeamsAsSpec
	end
	if data.renderAllTeamsAsPlayer ~= nil then
		renderAllTeamsAsPlayer = data.renderAllTeamsAsPlayer
	end
	spotterOpacity = data.spotterOpacity or spotterOpacity
end
