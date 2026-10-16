local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "LOS colors",
		desc = "custom colors for LOS",
		author = "[teh]decay (thx to Floris, BrainDamage, hokomoko, [teh]Teddy, Buttons840)",
		date = "23 jul 2015",
		license = "public domain",
		layer = 0,
		version = 4,
		enabled = true,
	}
end

--Changelog
-- v2 Changed colors + remember ; mode + fix keybindings for non english layouts + 2 color presets (/loswithcolors)
-- v3 Radar shading is always visible, and there is no option to colorize it.
--    Most players do not know about these settings, they are not in the setting UI, and do not have keybinds in grid.
-- v4 On engines with Engine.FeatureSupport.losInfoTexCodes, shaders/GLSL/infoLOS.lua writes
--    explicit level codes and the engine grades the map by luminance/saturation, so dark maps
--    are no longer crushed. There the LOS slider is "strength" and drives the InfoTexStrength
--    springsetting (0..1.25, default 1). Older engines keep the v3 colors and opacity unchanged.

local engineGrades = (Engine and Engine.FeatureSupport and Engine.FeatureSupport.losInfoTexCodes) and true or false

local STRENGTH_MIN, STRENGTH_MAX, STRENGTH_DEFAULT = 0, 1.25, 1

local opacity = 0.66
local strength = STRENGTH_DEFAULT
local strengthBeforeWidget

local losColors = {
	fog = { 0.40, 0.40, 0.40 },
	los = { 0.60, 0.60, 0.60 },
	radar = { 0.00, 0.00, 0.00 }, -- not used
	jam = { 0.03, -0.03, -0.03 }, -- additive tint: R-G/B spread sets how red jammed areas look (was 0.08)
	radar2 = { 0.40, 0.40, 0.40 },
}

local always, LOS, radar, jam, radar2
local spSetLosViewColors = Spring.SetLosViewColors

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function applyOpacity(colors)
	local newColors = table.copy(colors)
	for i, c in pairs(newColors.fog) do
		newColors.fog[i] = lerp(0, c, opacity)
	end
	for i, c in pairs(newColors.radar2) do
		-- move only half way towards opacity to give contract
		-- between radar and full fow
		newColors.radar2[i] = lerp(0, c, lerp(opacity, 1, 0.5))
	end
	return newColors
end

local function clampStrength(value)
	value = tonumber(value) or STRENGTH_DEFAULT
	return math.max(STRENGTH_MIN, math.min(STRENGTH_MAX, value))
end

local function updateLOS()
	if engineGrades then
		-- The engine reads InfoTexStrength every frame, so no refresh is needed.
		-- In-memory overlay only: the widget config owns the value.
		Spring.SetConfigFloat("InfoTexStrength", strength, true)
	else
		local colors = applyOpacity(losColors)
		spSetLosViewColors(colors.fog, colors.los, colors.radar, colors.jam, colors.radar2)
	end
end

function widget:Initialize()
	WG.los = {}
	WG.los.getOpacity = function()
		return opacity
	end
	WG.los.setOpacity = function(value)
		opacity = value
		updateLOS()
	end
	WG.los.getStrength = function()
		return strength
	end
	WG.los.setStrength = function(value)
		strength = clampStrength(value)
		updateLOS()
	end
	always, LOS, radar, jam, radar2 = Spring.GetLosViewColors()
	if engineGrades then
		strengthBeforeWidget = Spring.GetConfigFloat("InfoTexStrength", STRENGTH_DEFAULT)
	end

	updateLOS()
end

function widget:Shutdown()
	if engineGrades then
		-- hand back whatever was in effect before this widget, not a forced default
		Spring.SetConfigFloat("InfoTexStrength", strengthBeforeWidget or STRENGTH_DEFAULT, true)
	else
		spSetLosViewColors(always, LOS, radar, jam, radar2)
	end
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.strength ~= nil then
		strength = clampStrength(data.strength)
	end
end

function widget:GetConfigData()
	return {
		opacity = opacity,
		strength = strength,
	}
end
