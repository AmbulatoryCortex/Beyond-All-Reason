function widget:GetInfo()
	return {
		name = "Decals GL4",
		desc = "Try to draw some nice normalmapped decals",
		author = "Beherith",
		date = "2021.11.02",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = 999,
		enabled = false,
	}
end

-- Notes and TODO
-- yes these are geometry shader decals
-- we are gonna try to smaple heightmap
-- atlasColor is diffuse + alpha
	-- The color is expected to blend up to 0.5,
-- atlasNormals is normals + emission

-- advanced geoshader tricount for quads
-- 4x4 - 40
-- KNOWN BUG:
	-- the pop-back can change the render order of decals to be a tad annoying.... maybe a better method of managing this is needed?
	-- possibly solvable via batched decal removal, a good amount of time after they become transparent?
-- TODO:
	-- use global sun params for lighting calcs
	-- DONE disable parallax
	-- DONE enable support for old-style decals
	-- paint emission
	-- soften and make large decal creation above saturation threshold more probabilistic
	-- always allow the creation of small decals
	-- DONE control parallax via config
	-- SKIP fix parallax to work
	-- DONE Validate normals
	-- DONE decal fade-in?
	-- DONE cache decal UV's
	-- Add team/clan/etc sprays
		-- determine clan from first [] of playername
		-- which can be done on initialize?
		-- cursor
	-- DONE: SHADOWS SUPPORT!
	-- FOG SUPPORT?
	-- Better LOS SUPPORT
	-- DONE: BWfactor
	-- DONE: glowsustain
	-- DONE: glowadd
	-- Fix unused decals having 1.0 alpha in normal resulting in heavy glow on zoomed out small decals bleeding
------------------------ CONFIGURABLES -----------------------------------------------

local shaderConfig = {
	HEIGHTOFFSET = 0.5, -- Additional height added to everything
	LOSDARKNESS = 0.7, -- additional LOS darken factor
	PARALLAX = 0, -- 1 for on, kinda broken, do not use
	AMBIENTOCCLUSION = 0, -- 1 for on, do not use
	USEGLOW = 1, -- 1 for on, kinda wierd at the moment
	GLOWTHRESHOLD = 0.99,
	FADEINTIME = 24, -- number of frames to fade in over
	SPECULAREXPONENT = 5.0, -- how shiny decal surface is?
	SPECULARSTRENGTH = 0.3, -- how strong specular highlights are
	--BLACKANDWHITEFACTOR = 0.5, -- set to between [0,1] to set how strong the black and white conversion should be, 0 = original color, 1 = full black and white, deprecated, now controllable per-decal
	MINIMAPCOLORBLENDFACTOR = 1, -- How much minimap color should affect decal color
}

local groundscarsPath = "luaui/images/decals_gl4/groundscars/"	-- old: "luaui/images/decals_gl4/oldscars/"
local additionalcrap = {} -- a list of paths to also include for i dunno, sprays and stuff?

-- large decal resolution, 16x16 grid is ok
local resolution = 16 -- 32 is 2k tris, a tad pricey...
local largesizethreshold  = 512 -- if min(width,height)> than this, then we use the large version!
local extralargesizeThreshold = 1024 -- if min(width,height)> than this, then we use the extra large version!

local autoupdate = false -- auto update shader, for debugging only!


-- for automatic oversaturation prevention, not sure if it even works, but hey!
local areaResolution = 256 -- elmos per square, for a 64x map this is uh, big? for 32x32 its 4k
local saturationThreshold = 100 * areaResolution

------------------------ GL4 BACKEND -----------------------------------

local atlasColorAlpha = nil
local atlasNormals = nil
local atlasHeights = nil
local atlasRG = nil

local atlasSize = 4096
local atlasType = 1 -- 0 is legacy, 1 is quadtree type with no padding
-- ATLASTYPE 0 HAS WIIIIIIERD MINIFICATION ARTIFACTS!
-- atlastype 1 is da bomb
-- atlastype 2 seems oddly slow?
local atlassedImages = {}
local unitDefIDtoDecalInfo = {} -- key unitdef, table of {texfile = "", sizex = 4 , sizez = 4}
-- remember, we can use xXyY = gl.GetAtlasTexture(atlasID, texture) to query the atlas
local decalImageCoords = {} -- Key filepath, value is {p,q,s,t}

local function addDirToAtlas(atlas, path, key, filelist)
	if filelist == nil then filelist = {} end
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local files = VFS.DirList(path)
	--files = table.sort(files)
	--Spring.Echo("Adding",#files, "images to atlas from", path, key)
	for i=1, #files do
		local lowerfile = string.lower(files[i])
		if imgExts[string.sub(lowerfile,-3,-1)] and string.find(lowerfile, key, nil, true) then
			Spring.Echo(files[i])
			gl.AddAtlasTexture(atlas,lowerfile)
			atlassedImages[lowerfile] = atlas
			filelist[lowerfile] = true
		end
	end
	return filelist
end

local function makeAtlases()
	local success
	atlasColorAlpha = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)

	addDirToAtlas(atlasColorAlpha, groundscarsPath, '_a.', decalImageCoords)
	--addDirToAtlas(atlasColorAlpha, oldgroundscarsPath, 'scar', decalImageCoords)
	success = gl.FinalizeTextureAtlas(atlasColorAlpha)
	if success == false then return false end
	local atlasInfo = gl.TextureInfo(atlasColorAlpha)
	local usedpixels = 0
	-- read back the UVs:
	for filepath, _ in pairs(decalImageCoords) do
		local p,q,s,t = gl.GetAtlasTexture(atlasColorAlpha, filepath) --xXyY
		local texelX = 1.0/atlasInfo.xsize -- shrink UV areas for less mip bleed
		local texelY = 1.0/atlasInfo.ysize -- shrink UV areas for less mip bleed
		usedpixels = usedpixels + (math.abs(p-q) * atlasInfo.xsize ) * (math.abs(s-t) * atlasInfo.ysize)
		if autoreload then Spring.Echo(filepath) end 
		decalImageCoords[filepath] =  {p+texelX,q-texelX,s+texelY,t-texelY}
	end
	
	Spring.Echo(string.format("Decals GL4 Atlas is %dx%d, used %.1f%%", 
		atlasInfo.xsize, atlasInfo.ysize,
		usedpixels * 100 / (atlasInfo.xsize * atlasInfo.ysize)
		))

	atlasNormals = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)
	addDirToAtlas(atlasNormals, groundscarsPath, '_n.')
	success = gl.FinalizeTextureAtlas(atlasNormals)
	if success == false then return false end

	if shaderConfig.PARALLAX == 1 then
		atlasHeights = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)
		addDirToAtlas(atlasHeights, groundscarsPath, '_h.png')
		success = gl.FinalizeTextureAtlas(atlasHeights)
		if success == false then return false end
	end
	if shaderConfig.USEGLOW == 1 then
		atlasRG = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)
		addDirToAtlas(atlasRG, groundscarsPath, '_rg.png')
		success = gl.FinalizeTextureAtlas(atlasRG)
		if success == false then return false end
	end
	return true
end

local decalVBO = nil
local decalLargeVBO = nil
local decalExtraLargeVBO = nil

local decalShader = nil
local decalLargeShader = nil

local luaShaderDir = "LuaUI/Widgets/Include/"

--------------------------- Localization for faster access -------------------

local spGetGroundHeight = Spring.GetGroundHeight
local sqrt = math.sqrt
local diag = math.diag
local abs = math.abs

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local spValidUnitID = Spring.ValidUnitID

local spec, fullview = Spring.GetSpectatingState()



---- GL4 Backend Stuff----

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.frag.glsl"
local gsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.geom.glsl"

local vsSrcLargePath = "LuaUI/Widgets/Shaders/decals_large_gl4.vert.glsl"

local uniformInts =  {

	heightmapTex = 0,
	miniMapTex = 1,
	infoTex = 2,
	shadowTex = 3,
	mapNormalsTex = 4,
	atlasColorAlpha = 5,
	atlasNormals = 6,
	atlasHeights = ((shaderConfig.PARALLAX == 1) and 7 ) or nil,
	atlasORM = ((shaderConfig.AMBIENTOCCLUSION == 1) and 8 ) or nil,
	atlasRG = ((shaderConfig.USEGLOW == 1) and 9 ) or nil,
}

local shaderSourceCache = {
	vssrcpath = vsSrcPath,
	fssrcpath = fsSrcPath,
	gssrcpath = gsSrcPath,
	shaderConfig = shaderConfig,
	uniformInt = uniformInts,
	uniformFloat = {
		fadeDistance = 3000,
	},
	shaderName = "Decals Gl4 Shader",
}

local shaderLargeSourceCache = {
	vssrcpath = vsSrcLargePath,
	fssrcpath = fsSrcPath,
	shaderConfig = shaderConfig,
	uniformInt = uniformInts,
	uniformFloat = {
		fadeDistance = 3000,
	},
	shaderName = "Decals Large Gl4 Shader",
}

local function goodbye(reason)
  Spring.Echo("DrawPrimitiveAtUnits GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function initGL4( DPATname)
	decalShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	decalLargeShader = LuaShader.CheckShaderUpdates(shaderLargeSourceCache)

	if (not decalShader) or (not decalLargeShader) then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	decalVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthrotation', size = 4},
			{id = 1, name = 'uv_atlaspos', size = 4},
			{id = 2, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 3, name = 'worldPos', size = 4},
			{id = 4, name = 'parameters', size = 4},
		},
		64, -- maxelements
		DPATname .. "VBO" -- name
	)
	if decalVBO == nil then goodbye("Failed to create decalVBO") end

	local smallDecalVAO = gl.GetVAO()
	smallDecalVAO:AttachVertexBuffer(decalVBO.instanceVBO)
	decalVBO.VAO = smallDecalVAO

	local planeVBO, numVertices = makePlaneVBO(1,1,resolution,resolution)
	local planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution,resolution) --, true) -- add true to cull into a circle

	decalLargeVBO = makeInstanceVBOTable(
		{
			{id = 1, name = 'lengthwidthrotation', size = 4},
			{id = 2, name = 'uv_atlaspos', size = 4},
			{id = 3, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 4, name = 'worldPos', size = 4},
			{id = 5, name = 'parameters', size = 4},
		},
		64, -- maxelements
		DPATname .. "Large VBO" -- name
	)
	if decalLargeVBO == nil then goodbye("Failed to create decalLargeVBO") end

	decalLargeVBO.vertexVBO = planeVBO
	decalLargeVBO.indexVBO = planeIndexVBO
	decalLargeVBO.VAO = makeVAOandAttach(
		decalLargeVBO.vertexVBO,
		decalLargeVBO.instanceVBO,
		decalLargeVBO.indexVBO
	)

	planeVBO, numVertices = makePlaneVBO(1,1,resolution*4,resolution*4)
	planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution*4,resolution*4) --, true) -- add true to cull into a circle

	decalExtraLargeVBO = makeInstanceVBOTable(
		{
			{id = 1, name = 'lengthwidthrotation', size = 4},
			{id = 2, name = 'uv_atlaspos', size = 4},
			{id = 3, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 4, name = 'worldPos', size = 4},
			{id = 5, name = 'parameters', size = 4},
		},
		64, -- maxelements
		DPATname .. "Extra Large VBO" -- name
	)
	if decalExtraLargeVBO == nil then goodbye("Failed to create decalExtraLargeVBO") end

	decalExtraLargeVBO.vertexVBO = planeVBO
	decalExtraLargeVBO.indexVBO = planeIndexVBO
	decalExtraLargeVBO.VAO = makeVAOandAttach(
		decalExtraLargeVBO.vertexVBO,
		decalExtraLargeVBO.instanceVBO,
		decalExtraLargeVBO.indexVBO
	)
	return decalLargeVBO ~= nil and decalVBO ~= nil and decalExtraLargeVBO ~= nil
end

local decalIndex = 0
local decalTimes = {} -- maps instanceID to expected fadeout timeInfo
local decalRemoveQueue = {} -- maps gameframes to list of decals that will be removed
local decalRemoveList = {} -- maps instanceID's of decals that need to be batch removed to preserve order

-----------------------------------------------------------------------------------------------
-- This part is kinda useless for now, but we could prevent or control excessive decal spam right here!

local decalToArea = {} -- maps instanceID to a position key on the map
local areaDecals = {} -- {positionkey = {decallist, totalarea},}
local floor = math.floor

local function hashPos(mapx, mapz) -- packs XZ into 1000*x + z
	if mapx == nil or mapz == nil then
		Spring.Debug.TraceFullEcho()
	end

	return floor(mapx / areaResolution) * 1000 + floor(mapz/areaResolution)
end

local function initAreas()
	for x= areaResolution /2, Game.mapSizeX, areaResolution do
		for z= areaResolution /2, Game.mapSizeZ, areaResolution do
			local gh = spGetGroundHeight(x,z)
			areaDecals[hashPos(x,z)] = {instanceIDs = {}, totalarea = 0, x = x, y = gh, z = z, smoothness = 0}
		end
	end
end

local function AddDecalToArea(instanceID, posx, posz, width, length)
	local hash = hashPos(posx,posz)
	local maparea = areaDecals[hash]
	if maparea == nil then return end
	local area = width * length
	maparea.instanceIDs[instanceID] =  area
	maparea.totalarea = maparea.totalarea + area
	decalToArea[instanceID] = hash
end

local function RemoveDecalFromArea(instanceID)
	local hashpos = decalToArea[instanceID]
	if hashpos then
		local maparea = areaDecals[hashpos]
		if maparea and maparea.instanceIDs[instanceID] then
			maparea.totalarea = math.max(0,maparea.totalarea - maparea.instanceIDs[instanceID])
			maparea.instanceIDs[instanceID] = nil
		end
		decalToArea[instanceID] = nil
	end
end

local function CheckDecalAreaSaturation(posx, posz, width, length)
	local hash = hashPos(posx,posz)
	--Spring.Echo(hash,posx,posz, next(areaDecals))
	if not hash then
		return false
	else
		local areaD = areaDecals[hashPos(posx,posz)]
		if not areaD then
			return false
		else
			return (math.sqrt(areaD.totalarea) > saturationThreshold)
		end
	end
end

local updatePositionX = 0
local updatePositionZ = 0
function widget:Update() -- this is pointlessly expensive!
	if autoupdate then
		decalShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or decalShader
		decalLargeShader = LuaShader.CheckShaderUpdates(shaderLargeSourceCache) or		decalLargeShader
	end

	if true then return end
	-- run over the map, one area per frame, and calc its smoothness
	updatePositionX = updatePositionX + areaResolution
	if updatePositionX >= Game.mapSizeX then
		updatePositionX = 0
		updatePositionZ = updatePositionZ + areaResolution
		if updatePositionZ >= Game.mapSizeZ then
			updatePositionZ = 0
		end
	end
	if updatePositionX == nil or updatePositionZ == nil then
		Spring.Echo("updatePositionX == nil or updatePositionZ == nil")
		return
	end
	local hash = hashPos(updatePositionX, updatePositionZ)
	--Spring.Echo("Updateing smoothness at",updatePositionX, updatePositionZ)
	local step = areaResolution/ 16
	local totalheight = 0
	local numsamples = 0
	local totalsmoothness = 0
	local prevHeight = spGetGroundHeight(updatePositionX, updatePositionZ)
	local prevX = prevHeight
	for x = updatePositionX, updatePositionX + areaResolution, step do
		for z = updatePositionZ, updatePositionZ + areaResolution, step do
			local h = spGetGroundHeight(x,z)
			--numsamples = numsamples + 1
			--totalheight = totalheight + h
			--local avgheight = totalheight / numsamples
			--totalsmoothness = totalsmoothness + abs(h-avgheight)
			totalsmoothness = totalsmoothness + abs(h-prevHeight)
			prevHeight = h
		end
		prevX = prevHeight
	end
	areaDecals[hash].smoothness = totalsmoothness
end

local function DrawSmoothness()
	gl.Color(1,1,1,1)
	for areaHash, areaInfo in pairs(areaDecals) do
		--Spring.Echo(areaHash, areaInfo.x, areaInfo.y, areaInfo.z)
		if Spring.IsSphereInView(areaInfo.x, areaInfo.y, areaInfo.z, 128) then
			gl.PushMatrix()
			local text = string.format("Smoothness = %d",areaInfo.smoothness)
			local w = gl.GetTextWidth(text) * 16.0
			gl.Translate(areaInfo.x - w, areaInfo.y + 64, areaInfo.z)
			gl.Text( text,0,0,16,'n')
			gl.PopMatrix()
		end
	end
end

-----------------------------------------------------------------------------------------------

local function AddDecal(decaltexturename, posx, posz, rotation,
	width, length,
	heatstart, heatdecay, alphastart, alphadecay,
	maxalpha,
	bwfactor, glowsustain, glowadd, spawnframe)
	-- Documentation
	-- decaltexturename, full path to the decal texture name, it must have been added to the atlasses, e.g. 'bitmaps/scars/scar1.bmp'
	-- posx, posz, world pos to place center of decal
	-- rotation: rotation around y in radians
	-- width, length in elmos
	-- TODO: heatstart: the initial temperature, in kelvins of the emissive parts (alpha channel of normal texture)
	-- TODO: heatdecay: the exponential rate at which the hot parts are cooled down each frame
	-- alphastart: The initial transparency amount, can be > 1 too
	-- alphadecay: How much alpha is reduced each frame, when alphastart/alphadecay goes below 0, the decal will get automatically removed.
	-- maxalpha: The highest amount of transparency this decal can have
	-- bwfactor: the mix factor of the diffuse texture to black and whiteness, 0 is original cololr, 1 is black and white
	-- glowsustain: how many frames to elapse before glow starts to recede
	-- glowadd: how much additional, non-transparency controlled heat glow should the decal get
	heatstart = heatstart or 0
	heatdecay = heatdecay or 1
	alphastart = alphastart or 1
	alphadecay = alphadecay or 0

	bwfactor = bwfactor or 1 -- default force to black and white
	glowsustain = glowsustain or 1 -- how many frames to keep max heat for
	glowadd = glowadd or 0 -- how much additional additive glow to add

	if CheckDecalAreaSaturation(posx, posz, width, length) then
		Spring.Echo("Map area is oversaturated with decals!", posx, posz, width, length)
		return nil
	else

	end

	spawnframe = spawnframe or Spring.GetGameFrame()
	--Spring.Echo(decaltexturename, atlassedImages[decaltexturename], atlasColorAlpha)
	local p,q,s,t = 0,1,0,1

	--Spring.Echo(decaltexturename) --used for displaying which decal texture is spawned
	if decalImageCoords[decaltexturename] == nil then
		Spring.Echo("Tried to spawn a decal gl4 with a texture not present in the atlas:",decaltexturename)
	else
		local uvs = decalImageCoords[decaltexturename]
		p,q,s,t = uvs[1], uvs[2], uvs[3], uvs[4]
	end

	local posy = Spring.GetGroundHeight(posx, posz)
	--Spring.Echo (unitDefID,decalInfo.texfile, width, length, alpha)
	-- match the vertex shader on lifetime:
	-- 	float currentAlpha = min(1.0, (lifetonow / FADEINTIME))  * alphastart - lifetonow* alphadecay;
	--  currentAlpha = min(currentAlpha, lengthwidthrotation.w);
	local lifetime = math.floor(alphastart/alphadecay)
	decalIndex = decalIndex + 1
	local targetVBO = decalVBO

	if math.min(width,length) > extralargesizeThreshold then
		targetVBO = decalExtraLargeVBO
	elseif math.min(width,length) > largesizethreshold then
		targetVBO = decalLargeVBO
	end

	pushElementInstance(
		targetVBO, -- push into this Instance VBO Table
			{length, width, rotation, maxalpha ,  -- lengthwidthrotation maxalpha
			p,q,s,t, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
			alphastart, alphadecay, heatstart, heatdecay, -- alphastart_alphadecay_heatstart_heatdecay
			posx, posy, posz, spawnframe,

			bwfactor,glowsustain,glowadd,0}, -- params
		decalIndex, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
	local deathtime = spawnframe + lifetime
	decalTimes[decalIndex] = deathtime
	if decalRemoveQueue[deathtime] == nil then
		decalRemoveQueue[deathtime] = {decalIndex}
	else
		decalRemoveQueue[deathtime][#decalRemoveQueue[deathtime] + 1 ] = decalIndex
	end

	AddDecalToArea(decalIndex, posx, posz, width, length)
	return decalIndex, lifetime
end

function widget:DrawWorldPreUnit()
	if decalVBO.usedElements > 0 or decalLargeVBO.usedElements > 0 or decalExtraLargeVBO.usedElements > 0 then

		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		--Spring.Echo(decalVBO.usedElements,decalLargeVBO.usedElements)
		glCulling(GL.BACK)
		glDepthTest(GL_LEQUAL)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		glTexture(0, '$heightmap')
		glTexture(1, '$minimap')
		glTexture(2, '$info')
		glTexture(3, '$shadow')
		glTexture(4, '$normals')
		glTexture(5, atlasColorAlpha)
		glTexture(6, atlasNormals)
		if shaderConfig.PARALLAX == 1 then glTexture(7, atlasHeights) end
		if shaderConfig.AMBIENTOCCLUSION == 1 then glTexture(8, atlasRG) end
		if shaderConfig.USEGLOW == 1 then glTexture(9, atlasRG) end
		--glTexture(9, '$map_gbuffer_zvaltex')
		--glTexture(10, '$map_gbuffer_difftex')
		--glTexture(11, '$map_gbuffer_normtex')


		if decalVBO.usedElements > 0  then
			decalShader:Activate()
			decalShader:SetUniform("fadeDistance",disticon * 1000)
			decalVBO.VAO:DrawArrays(GL.POINTS, decalVBO.usedElements)
			decalShader:Deactivate()
		end

		if decalLargeVBO.usedElements > 0 or decalExtraLargeVBO.usedElements > 0 then
			--Spring.Echo("large elements:", decalLargeVBO.usedElements)
			decalLargeShader:Activate()
			--decalLargeShader:SetUniform("fadeDistance",disticon * 1000)
			if decalLargeVBO.usedElements > 0 then
				decalLargeVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, decalLargeVBO.usedElements, 0)
			end
			if decalExtraLargeVBO.usedElements > 0 then
				decalExtraLargeVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, decalExtraLargeVBO.usedElements, 0)
			end
			decalLargeShader:Deactivate()
		end

		-- Restore the GL state
		for i = 0, 8 do glTexture(i, false) end
		glCulling(GL.BACK) -- This is the correct default mode!
		glDepthTest(GL_LEQUAL)
		--gl.Blending(GL.SRC_ALPHA, GL.ONE)

		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- the default mode

		--gl.DepthMask(false) --"BK OpenGL state resets", already set as false

		if false then
			local tricount = 4*4*2 * decalVBO.usedElements + resolution*resolution*2*decalLargeVBO.usedElements + 4*4*resolution*resolution*2*decalExtraLargeVBO.usedElements
			Spring.Echo(string.format("Small decal = %d, Medium decal = %d, Large decal = %d, tris = %d",
				decalVBO.usedElements,
				decalLargeVBO.usedElements,
				decalExtraLargeVBO.usedElements,
				tricount))
		end
	end
end

local function RemoveDecal(instanceID)
	RemoveDecalFromArea(instanceID)
	if decalVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(decalVBO, instanceID)
	elseif decalLargeVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(decalLargeVBO, instanceID)
	elseif decalExtraLargeVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(decalExtraLargeVBO, instanceID)
	end
	decalTimes[instanceID] = nil
end

function widget:GameFrame(n)
	if decalRemoveQueue[n] then
		for i=1, #decalRemoveQueue[n] do
			local decalID = decalRemoveQueue[n][i]
			decalRemoveList[decalID] = true
			--RemoveDecal(decalID)
		end
		decalRemoveQueue[n] = nil
	end

	if n % 91 == 0 then
		local removed = 0
		removed = removed + compactInstanceVBO(decalVBO, decalRemoveList)
		removed = removed + compactInstanceVBO(decalLargeVBO, decalRemoveList)
		removed = removed + compactInstanceVBO(decalExtraLargeVBO, decalRemoveList)
		decalRemoveList = {}

		if autoupdate and removed > 0 then
			Spring.Echo("Removed",removed,"decals from decal instance tables: s=",decalVBO.usedElements,' l=', decalLargeVBO.usedElements,'xl=', decalExtraLargeVBO.usedElements)
		end
		if removed > 0 then
			uploadAllElements(	decalVBO)
			uploadAllElements(	decalLargeVBO)
			uploadAllElements(	decalExtraLargeVBO)
		end
	end
end

local function randtablechoice (t)
	local i = 0
	for _ in pairs(t) do i = i+1 end
	local randi = math.floor(math.random()*i)
	local j = 0
	for k,v in pairs(t) do
		if j > randi then return k,v end
		j = j+1
	end
	return next(t)
end

function widget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID) -- This callin is not registered!
	---Spring.Echo("widget:Explosion",weaponDefID, px, py, pz, AttackerID, ProjectileID)
end

local function GadgetWeaponExplosionDecal(px, py, pz, weaponID, ownerID)
	local weaponDef = WeaponDefs[weaponID]
	--Spring.Echo("GadgetWeaponExplosionDecal",px, py, pz, weaponID, ownerID, weaponDef.damageAreaOfEffect, weaponDef.name)
	
	local aa = string.find(weaponDef.cegTag, 'aa')
	if aa then
		return
	end

	-- randomly choose one decal
	local heatstart = 0
	local idx --= randtablechoice(decalImageCoords)
	local heatdecay = math.random() + 1.1
	-- Or hard code it:
	if true then
		if math.random(1,3) == 1 then
			idx = groundscarsPath.."t_groundcrack_17_a.png"
		elseif math.random(1,3) == 2 then
			idx = groundscarsPath.."t_groundcrack_21_a.png"
		else
			idx = groundscarsPath.."t_groundcrack_10_a.png"
		end
		--idx = groundscarsPath.."t_groundcrack_09_a.png"
		heatstart = (math.random() * 0.2 + 0.9) * 4900
		heatdecay = (math.random() * 0.4 + 2.0) - (weaponDef.damageAreaOfEffect/2250)
	end

	local radius = (weaponDef.damageAreaOfEffect * 1.4) * (math.random() * 0.48 + 0.72)
	local gh = spGetGroundHeight(px,pz)
	-- dont spawn decals into the air
	-- also, modulate their alphastart by how far above ground they are
	local exploheight = py - gh
	if (exploheight >= radius) then return end

		-- reduce severity when explosion is above ground
	local heightMult = 1 - (exploheight / radius)
	local alpha = (math.random() * 1.0 + 1.5) * (1.0 - exploheight/radius) * heightMult
	local alphadecay = (math.random() * 0.3 + 0.2) / (4 * radius)
	local bwfactor = 0.5 --the mix factor of the diffuse texture to black and whiteness, 0 is original cololr, 1 is black and white
	local glowsustain = math.random() * 20 -- how many frames to elapse before glow starts to recede
	local glowadd = math.random() * 2 -- how much additional, non-transparency controlled heat glow should the decal get

	if weaponDef.paralyzer then
		if math.random(1,3) == 1 then
			idx = groundscarsPath.."t_groundcrack_17_a.png"
		else
			idx = groundscarsPath.."t_groundcrack_10_a.png"
		end
		heatstart = 0
		glowadd = 0
	end

	-- if weaponDef.type == 'DGun' then
	-- 	idx = groundscarsPath.."t_groundcrack_16_a.png"
	-- 	radius = radius * 2.5
	-- 	heatdecay = 0.6
	-- 	bwfactor = 0

	if string.find(weaponDef.name, 'juno') then
		radius = 180

	elseif string.find(weaponDef.name, 'disintegrator') then
	  if math.random(1,2) == 1 then
			idx = groundscarsPath.."t_groundcrack_16_a.png"
		else
			idx = groundscarsPath.."t_groundcrack_17_a.png"
		end
   	radius = radius * 2.5
	 	heatdecay = 0.7
	 	glowsustain = 40
	 	glowadd = 2.5
	 	bwfactor = 0

	elseif string.find(weaponDef.name, 'acid') then
		idx = groundscarsPath.."t_groundcrack_26_a.png"
		alpha = 6
		radius = (radius * 5) * (math.random() * 0.15 + 0.85)
		heatstart = 500
		heatdecay = 10
		alphadecay = 0.012
		--glowadd = 2.5
		--glowsustain = 0
		bwfactor = 0.17 --0.17
	

	elseif string.find(weaponDef.name, '.advbomb') then
		--idx = groundscarsPath.."t_groundcrack_09_a.png"
		radius = radius * 1.5
		heatstart = 5500
		heatdecay = 2.0
		glowsustain = 35
		glowadd = 4
		bwfactor = 0.01

	elseif string.find(weaponDef.name, '.bomb') then
		--idx = groundscarsPath.."t_groundcrack_09_a.png"
		radius = radius * 0.8
		heatstart = 3500
		heatdecay = 2.7
		glowsustain = 20
		glowadd = 1.2
		bwfactor = 0.01

	elseif string.find(weaponDef.name, 'nuketestcor') then
		idx = groundscarsPath.."t_groundcrack_21_a.png"
		--radius = radius * 1.2
		heatstart = 5500
		heatdecay = 0.5
		glowsustain = 150
		glowadd = 1.5
		bwfactor = 0.1

	elseif string.find(weaponDef.name, 'nuketest') then
		idx = groundscarsPath.."t_groundcrack_21_a.png"
		--radius = radius * 1.2
		heatstart = 5500
		heatdecay = 0.5
		glowsustain = 150
		glowadd = 1.5
		bwfactor = 0.1

	elseif string.find(weaponDef.name, 'nuclear_missile') then
		idx = groundscarsPath.."t_groundcrack_21_a.png"
		--radius = radius * 1.2
		heatstart = 5500
		heatdecay = 0.5
		glowsustain = 150
		glowadd = 1.5
		bwfactor = 0.1

	elseif string.find(weaponDef.name, 'crblmssl') then
		idx = groundscarsPath.."t_groundcrack_21_a.png"
		--radius = radius * 1.8
		heatstart = 5500
		heatdecay = 0.5
		glowsustain = 125
		glowadd = 1.5
		bwfactor = 0.1

  --armliche 
	elseif string.find(weaponDef.name, 'arm_pidr') then
		idx = groundscarsPath.."t_groundcrack_21_a.png"
		radius = radius * 1.8
		heatstart = 5500
		heatdecay = 0.66
		glowsustain = 100
		glowadd = 1.5
		bwfactor = 0.1

	elseif string.find(weaponDef.name, 'juggernaut_fire') then
		if math.random(1,2) == 1 then
			idx = groundscarsPath.."t_groundcrack_16_a.png"
		else
			idx = groundscarsPath.."t_groundcrack_17_a.png"
		end
		--heatstart = 5500
		radius = radius * 2.4
		heatdecay = 0.65
		glowsustain = 40
		glowadd = 1.3
		bwfactor = 0.1

	elseif string.find(weaponDef.name, 'tremor') then
		if math.random(1,2) == 1 then
			idx = groundscarsPath.."t_groundcrack_21_a.png"
		else
			idx = groundscarsPath.."t_groundcrack_22_a.png"
		end
		alphadecay = 0.0024
		--bwfactor = 0.1

	elseif string.find(weaponDef.name, 'death_acid') then
		idx = groundscarsPath.."t_groundcrack_26_a.png"
		alpha = 6
		radius = (radius * 5.5) * (math.random() * 0.25 + 0.75)
		heatstart = 550
		heatdecay = 0.1
		alphadecay = 0.012
		glowadd = 2.5
		bwfactor = 0.17

	elseif string.find(weaponDef.name, 'bug') then
		if math.random(1,3) == 1 then
			idx = groundscarsPath.."t_groundcrack_23_a.png"
		elseif math.random(1,3) == 2 then
			idx = groundscarsPath.."t_groundcrack_24_a.png"
		else
			idx = groundscarsPath.."t_groundcrack_25_a.png"
		end
		alpha = 15
		radius = (radius * 10) * (math.random() * 0.7 + 0.52)
		heatstart = 490
		heatdecay = 0.1
		alphadecay = 0.002
		glowadd = 2.5
		bwfactor = 0.64

	elseif string.find(weaponDef.name, 'bloodyeggs') then
		idx = groundscarsPath.."t_groundcrack_23_a.png"
		alpha = 10
		radius = (radius * 1.5) * (math.random() * 1.2 + 0.25)
		heatstart = 490
		heatdecay = 0.1
		alphadecay = 0.005
		glowadd = 2.5
		bwfactor = 0.64

	elseif string.find(weaponDef.name, 'dodo') then
		if math.random(1,2) == 1 then
			idx = groundscarsPath.."t_groundcrack_23_a.png"
		else
			idx = groundscarsPath.."t_groundcrack_24_a.png"
		end
		alpha = 10
		radius = (radius * 1.2) * (math.random() * 0.15 + 0.85)
		heatstart = 490
		heatdecay = 0.1
		alphadecay = 0.002
		glowadd = 2.5
		bwfactor = 0.7

	end

	AddDecal(
		idx,
		px, --posx
		pz, --posz
		math.random() * 6.28, -- rotation
		radius, -- width
		radius, -- height
		heatstart * heightMult, -- heatstart
		heatdecay * (1+(1-heightMult)), -- heatdecay
		(math.random() * 0.38 + 0.72) * alpha, -- alphastart
		alphadecay, -- alphadecay
		math.random() * 0.2 + 0.8, -- maxalpha
		bwfactor,
		glowsustain,
		glowadd
	)
end

function widget:Initialize()
	if makeAtlases() == false then
		goodbye("Failed to init texture atlas for DecalsGL4")
		return
	end
	local initsuccess = initGL4("DecalsGL4")
	if initsuccess == nil then
		widgetHandler:RemoveWidget()
		return
	end
	initAreas()
	math.randomseed(1)
	if autoupdate then
		for i= 1, 100 do
			local w = math.random() * 15 + 7
			w = w * w
			local j = math.floor(math.random()*20+1)
			--local idx = string.format(groundscarsPath.."t_groundcrack_%02d_a.png", j)
			local idx = randtablechoice(decalImageCoords)
			--Spring.Echo(idx)
			AddDecal(
				idx,
				Game.mapSizeX * math.random() * 1.0, --posx
				Game.mapSizeZ * math.random() * 1.0, --posz
				math.random() * 6.28, -- rotation
				w, -- width
				w, --height
				math.random() * 10000, -- heatstart
				math.random() * 1, -- heatdecay
				math.random() * 1.0 + 1.0, -- alphastart
				math.random() * 0.001, -- alphadecay
				math.random() * 0.3 + 0.7 -- maxalpha
			)
		end
	end

	WG['decalsgl4'] = {}
	WG['decalsgl4'].AddDecalGL4 = AddDecal
	WG['decalsgl4'].RemoveDecalGL4 = RemoveDecal
	widgetHandler:RegisterGlobal('AddDecalGL4', WG['decalsgl4'].AddDecalGL4)
	widgetHandler:RegisterGlobal('RemoveDecalGL4', WG['decalsgl4'].RemoveDecalGL4)
	widgetHandler:RegisterGlobal('GadgetWeaponExplosionDecal', GadgetWeaponExplosionDecal)
end



function widget:ShutDown()
	if atlasColorAlpha ~= nil then
		gl.DeleteTextureAtlas(atlasColorAlpha)
	end
	if atlasHeights ~= nil then
		gl.DeleteTextureAtlas(atlasHeights)
	end
	if atlasNormals ~= nil then
		gl.DeleteTextureAtlas(atlasNormals)
	end
	if atlasRG ~= nil then
		gl.DeleteTextureAtlas(atlasRG)
	end

	WG['decalsgl4'] = nil
	widgetHandler:DeregisterGlobal('AddDecalGL4')
	widgetHandler:DeregisterGlobal('RemoveDecalGL4')
	widgetHandler:DeregisterGlobal('GadgetWeaponExplosionDecal')
end
