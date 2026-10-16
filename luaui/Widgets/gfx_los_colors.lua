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
-- v4 Stopgap so dark maps stay readable. The terrain shader does
--    diffuse += infoTex - 0.5, so levels below 0.5 darken every map by a
--    flat amount. Defaults now sit just under 0.5. The los-opacity slider
--    still moves fog and radar, and cannot push radar up into air LOS.

local DEFAULT_OPACITY = 0.66
local opacity = DEFAULT_OPACITY

-- Gray levels passed to Spring.SetLosViewColors at the default slider position.
-- Ground LOS (`los`) is not scaled. Air-only LOS is a separate 0.52 step in
-- shaders/GLSL/infoLOS.lua and has to stay the step above radar.
-- Ordering, brightest first: ground LOS 0.60 > air-only 0.52 > radar > fog.
local losColors = {
	fog = { 0.44, 0.44, 0.44 },
	los = { 0.60, 0.60, 0.60 },
	radar = { 0.00, 0.00, 0.00 }, -- not used
	jam = { 0.03, -0.03, -0.03 }, -- additive tint: R-G/B spread sets how red jammed areas look (was 0.08)
	radar2 = { 0.46, 0.46, 0.46 },
}

-- Slider ends (opacity 0 and 1). Radar stays above fog and below the air-only
-- step across the whole slider. The dark end is about as dark as the old default.
local FOG_DARK, FOG_LIGHT = 0.24, 0.48
local RADAR_DARK, RADAR_LIGHT = 0.30, 0.50

local always, LOS, radar, jam, radar2
local spSetLosViewColors = Spring.SetLosViewColors

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(value)
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

-- opacity == DEFAULT_OPACITY returns `value` unchanged. Below that, fade
-- toward the dark end; above it, fade toward the light end. A straight
-- scale of the old bases would put fog above radar (and above air LOS)
-- at the top of the slider.
local function remapAroundDefault(value, dark, light)
	if opacity <= DEFAULT_OPACITY then
		return lerp(dark, value, opacity / DEFAULT_OPACITY)
	end
	return lerp(value, light, (opacity - DEFAULT_OPACITY) / (1 - DEFAULT_OPACITY))
end

local function applyOpacity(colors)
	local newColors = table.copy(colors)
	local fog = remapAroundDefault(colors.fog[1], FOG_DARK, FOG_LIGHT)
	local radar = remapAroundDefault(colors.radar2[1], RADAR_DARK, RADAR_LIGHT)
	for i = 1, 3 do
		newColors.fog[i] = fog
		newColors.radar2[i] = radar
	end
	return newColors
end

local function updateLOS()
	local colors = applyOpacity(losColors)
	spSetLosViewColors(colors.fog, colors.los, colors.radar, colors.jam, colors.radar2)
end

function widget:Initialize()
	WG.los = {}
	WG.los.getOpacity = function()
		return opacity
	end
	WG.los.setOpacity = function(value)
		opacity = clamp01(value)
		updateLOS()
	end
	always, LOS, radar, jam, radar2 = Spring.GetLosViewColors()

	updateLOS()
end

function widget:Shutdown()
	spSetLosViewColors(always, LOS, radar, jam, radar2)
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = clamp01(data.opacity)
	end
end

function widget:GetConfigData()
	return {
		opacity = opacity,
	}
end
