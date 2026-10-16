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
-- v4 On engines that register the InfoTexStrength springsetting, shaders/GLSL/infoLOS.lua
--    writes explicit level codes and the engine grades the map by luminance/saturation
--    (dark maps are no longer crushed). The old "opacity" slider becomes "strength",
--    which drives InfoTexStrength (0..1.25, default 1). Colors below are only used on
--    older engines, where the legacy gray overlay is still drawn.

local STRENGTH_MIN, STRENGTH_MAX, STRENGTH_DEFAULT = 0, 1.25, 1
local LEGACY_OPACITY = 0.66

local spGetConfigFloat = Spring.GetConfigFloat
local spSetConfigFloat = Spring.SetConfigFloat
local spSetLosViewColors = Spring.SetLosViewColors

-- InfoTexStrength is registered (and so has a default) only on engines that decode the codes.
local engineGrades = (spGetConfigFloat("InfoTexStrength", -1) >= 0)

local strength = STRENGTH_DEFAULT

local losColors = {
	fog = { 0.40, 0.40, 0.40 },
	los = { 0.60, 0.60, 0.60 },
	radar = { 0.00, 0.00, 0.00 }, -- not used
	jam = { 0.03, -0.03, -0.03 }, -- additive tint: R-G/B spread sets how red jammed areas look (was 0.08)
	radar2 = { 0.40, 0.40, 0.40 },
}

local always, LOS, radar, jam, radar2

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clampStrength(value)
	value = tonumber(value) or STRENGTH_DEFAULT
	return math.max(STRENGTH_MIN, math.min(STRENGTH_MAX, value))
end

-- legacy path only: map strength (default 1) onto the old opacity (default 0.66)
local function applyOpacity(colors)
	local opacity = math.min(1, LEGACY_OPACITY * strength / STRENGTH_DEFAULT)
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

local function updateLOS()
	if engineGrades then
		-- The engine reads InfoTexStrength every frame, so no refresh is needed.
		-- Not persisted to springsettings: the widget config owns the value.
		spSetConfigFloat("InfoTexStrength", strength, true)
	else
		local colors = applyOpacity(losColors)
		spSetLosViewColors(colors.fog, colors.los, colors.radar, colors.jam, colors.radar2)
	end
end

function widget:Initialize()
	WG.los = {}
	WG.los.getStrength = function()
		return strength
	end
	WG.los.setStrength = function(value)
		strength = clampStrength(value)
		updateLOS()
	end
	always, LOS, radar, jam, radar2 = Spring.GetLosViewColors()

	updateLOS()
end

function widget:Shutdown()
	if engineGrades then
		spSetConfigFloat("InfoTexStrength", STRENGTH_DEFAULT, true)
	else
		spSetLosViewColors(always, LOS, radar, jam, radar2)
	end
end

function widget:SetConfigData(data)
	if data.strength ~= nil then
		strength = clampStrength(data.strength)
	end
	-- the old "opacity" (default 0.66) is not carried over: it set fog/radar
	-- colors, and its scale does not match InfoTexStrength
end

function widget:GetConfigData()
	return {
		strength = strength,
	}
end
