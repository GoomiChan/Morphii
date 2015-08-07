--========================================
-- Morphii
-- Facial morph UI
-- Arkii      25/07/15
--========================================
require 'unicode'
require "lib/lib_Debug"
require "lib/lib_Slash"
require "lib/lib_Callback2"
require "lib/lib_math"
require "lib/lib_Vector"
require "lib/lib_table"
require "lib/lib_WebCache"
require "./lib/lib_SimpleDialog"

--=====================
--		Constants    --
--=====================
local C = 
{
	OPTIONS = Component.GetFrame("Options"),
	CUSTOMIZE_OPTIONS = Component.GetWidget("CustomizeOptions"),
	VIEWER_OPTIONS = Component.GetWidget("ViewerOptions"),
	DEBUG_TXT = Component.GetWidget("DebugTxt"),
	MODEL_DRAG = Component.GetWidget("ModelDrag"),
	PRESETS = Component.GetWidget("PresetsDD"),
	PRESETS_SAVE_BUTTON = Component.GetWidget("PresetsSaveButton"),
	PRESETS_DELETE_BUTTON = Component.GetWidget("PresetsDeleteButton"),
	TEXT_INPUT_POPUP = Component.GetWidget("TextInputPopUp"),
	DARK_SOULS = Component.GetWidget("DarkSouls"),
	SIN_ZONE = "default",
	MORPH_NAMES =
	{
		"Nope",
		"Eye Size",
		"Eye Shape",
		"Eye Tilt",
		"Eye Angle",
		"Eye Width",
		"Eye Height",
		"Eyebrow Height",
		"Ear Angle",
		"Nose Twist",
		"Nose Size",
		"Nose Width",
		"Nose Height",
		"Nostril Width",
		"Left Mouth Angle",
		"Right Mouth Angle",
		"Mouth Width",
		"Mouth Height",
		"Chin Length",
		"Chin Width",
		"Upper Cheek Size",
		"Lower Cheek Size"
	},
	MORPH_GROUPS = 
	{
		{ name="Eye", 		morphs = { 2,3,4,5,6,7,8 } },
		{ name="Ear", 		morphs = { 9 } },
		{ name="Nose", 		morphs = { 10,11,12,13,14 } },
		{ name="Mouth", 	morphs = { 15,16,17,18 } },
		{ name="Chin", 		morphs = { 19,20 } },
		{ name="Cheeks", 	morphs = { 21,22 } },
	},
	CAMERAS =
	{
		["far"] = 		 	{pos={x=0, y=-4.75, z=2.0}, aim={x=0, y=0, z=2.7}, fov=45},
		["head_front"] = 	{pos={x=0, y=-1.5, z=2.9}, aim={x=0, y=0, z=3.15}, fov=45}
	},
	DARK_SOULS_LEVELS = 
	{
		"Off",
		"Mild Souls",
		"Dark Souls",
		"Dank Souls",
		"Dear God Why!!, Souls"
	},
	MORPH_PRESETS_KEY = "MorphPresets",
	MORPH_PRESET_PREFIX = "Morph_",
	CATEGORY_CLOSED_HEIGHT = 40,
	SLIDER_HEIGHT = 40,
	MODEL_LERP_SPEED = 3.5,
	MIN_ZOOM = 0,
	MAX_ZOOM = 0.3,
	ZOOM_LERP_SPEED = 2.5,
	MODEL_ROTATE_BUTTON_SPEED = 75,
	BUTTON_CLICK_SND = "Play_UI_Beep_Short_04"
}

--=====================
--		Varables     --
--=====================
local g_IsOpen = false
local g_PlayerMdlId = nil
local g_MorphCategories = {}
local g_Morphs = nil
local g_NumMorphs = 0
local g_MousePos = {x=0, y=0}
local g_modelRotationSpeed = 0
local g_modelRotationAccel = 0
local g_modelRotationAngle = 180
local g_MouseDragCallback = nil
local g_ModelRotCycle = nil
local g_ModelLerpToAngle = nil
local g_CamZoomCb = nil
local g_CurrentCam = nil
local g_ActiveCamPreset = ""
local g_CurrentCamZoom = 0
local g_MouseOverModel = false
local g_Presets = {}
local g_ActivePreset = {name="Default"}
local g_Gender = ""
local g_DarkSoulsValue = 1

--=====================
--      Events       --
--=====================
function OnComponentLoad(args)
	LIB_SLASH.BindCallback({slash_list = "mo", description = "", func=OnSlash})

	g_ModelRotCycle = Callback2.CreateCycle(ModelLerpDo)

	C.DARK_SOULS:GetChild("Value"):SetText(C.DARK_SOULS_LEVELS[1])
end

function OnPlayerReady(args)
	DestroyCategories()
	CreateMorphSliders()
end

--=====================
--		Callacks     --
--=====================
function OnSlash(args)
	if args.text == "" then
		if not g_IsOpen then
			Open()
		else
			Close()
		end
	end
end

-- When a category is expanded, closed
function OnToggleCategory(args)
	local cat = g_MorphCategories[args.id]
	if cat then
		if cat.isOpen then
			ToggleCategory(cat, false)
			cat.isOpen = false
		else
			ToggleCategory(cat, true)
			cat.isOpen = true
		end
	end
end

function OnResolutionChanged(args)
	SetUiPosition()
end

-- Camera buttons
function OnSwapCamLeft()
	SwapCamera("head_front")
	ModelLerpTo(270)
	System.PlaySound(C.BUTTON_CLICK_SND)
end

function OnSwapCamRight()
	SwapCamera("head_front")
	ModelLerpTo(90)
	System.PlaySound(C.BUTTON_CLICK_SND)
end

function OnSwapCamFront()
	SwapCamera("head_front")
	ModelLerpTo(180)
	System.PlaySound(C.BUTTON_CLICK_SND)
end

function OnSwapCamFar()
	SwapCamera("far")
	System.PlaySound(C.BUTTON_CLICK_SND)
end

function OnModelDragDown()
	g_MousePos.x, g_MousePos.y = Component.GetCursorPos()
	DoMouseDrag()
end

function OnModelDragUp()
	Component.ClearGlobalCursorOverride()
end

function OnDisplayHair(args)
	if args.checked then
		local info = Player.GetCharacterInfo()
		Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "head_accessory_a", info.headAccA)
	else
		Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "head_accessory_a", nil)
	end
end

function OnDisplayBattleframe(args)
	if args.checked then
		local loadout = Player.GetCurrentLoadout()
		Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "main_armor", loadout.item_types.chassis)
		Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "backpack", loadout.item_types.backpack)
	else
		Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "main_armor", 75662)
		Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "backpack", nil)
	end
end

function OnDisplayOrnaments(args)
	local info = Player.GetCharacterInfo()

	for idx,ornament_id in pairs(info.visuals.ornament_group_ids) do
		Sinvironment.LoadCharacterOrnament(g_PlayerMdlId, idx, args.checked and ornament_id or nil)
	end
end

function OnModelZoom(args)
	SetCameraZoom(g_CurrentCamZoom - (args.amount * 0.05))
end

function OnLeftRotateDown()
	g_MousePos.x, g_MousePos.y = Component.GetCursorPos()
	g_MousePos.x = g_MousePos.x + C.MODEL_ROTATE_BUTTON_SPEED
	DoMouseDrag()

	if Component.GetMouseButtonState() then
		Callback2.FireAndForget(OnLeftRotateDown, nil, .05)
	end
end

function OnRightRotateDown()
	g_MousePos.x, g_MousePos.y = Component.GetCursorPos()
	g_MousePos.x = g_MousePos.x - C.MODEL_ROTATE_BUTTON_SPEED
	DoMouseDrag()

	if Component.GetMouseButtonState() then
		Callback2.FireAndForget(OnRightRotateDown, nil, .05)
	end
end

function OnSinModelMouseover(args)
	g_MouseOverModel = args.focused

	if args.focused then
		Component.ClearGlobalCursorOverride()
		Component.SetGlobalCursorOverride("sys_hand_open", false)
	elseif g_MouseDragCallback == nil then
		Component.ClearGlobalCursorOverride()
	end
end

function OnResetAllDefaults()
	g_Morphs = nil
	DestroyCategories()
	CreateMorphSliders()
	SetMorphs()
	System.PlaySound(C.BUTTON_CLICK_SND)
end

function OnPresetSelected(args)
	local sel_index = select(2, C.PRESETS:GetSelected())

	C.PRESETS_DELETE_BUTTON:Enable()
	C.PRESETS_SAVE_BUTTON:Enable()
	if sel_index == 1 then -- Defaults
		SetToDefaults()
		C.PRESETS_DELETE_BUTTON:Disable()
		C.PRESETS_SAVE_BUTTON:Disable()

	elseif sel_index == #g_Presets+2 then -- Add a new one
		AddNewLookPreset()

	else -- Saved preset
		LoadAndApplyLook(sel_index)

	end
end

function OnPresetSave()
	SaveLook(g_ActivePreset.name)
	System.PlaySound(C.BUTTON_CLICK_SND)
end

function OnPresetDelete()
	ShowDialog({
		body="Are you sure you want to delete this preset: "..g_ActivePreset.name.."?",
		onYes = function()
			if g_ActivePreset.index then
				table.remove(g_Presets, g_ActivePreset.index)
				DeleteLook(g_ActivePreset.name)
				SavePresets()
				LoadPresets()
				OnPresetSelected()
			end
		end
	})
	System.PlaySound(C.BUTTON_CLICK_SND)
end

function OnToggleUIControls()
	C.CUSTOMIZE_OPTIONS:Show(not C.CUSTOMIZE_OPTIONS:IsVisible())
	C.VIEWER_OPTIONS:Show(not C.VIEWER_OPTIONS:IsVisible())
	System.PlaySound(C.BUTTON_CLICK_SND)
end

-- Just a bit of fun :>
function OnDarkSouls(args)
	local pct = C.DARK_SOULS:GetChild("Adjuster"):GetPercent()
	g_DarkSoulsValue = math.floor((#C.DARK_SOULS_LEVELS-1)*pct)+1
	local souls = C.DARK_SOULS_LEVELS[g_DarkSoulsValue]
	C.DARK_SOULS:GetChild("Value"):SetText(souls)
end

--=====================
--		Functions    --
--=====================
function Open()
	LoadPresets()
	CreateSInEnviro()
	C.OPTIONS:Show(true)
	SwapCamera("head_front")
	g_IsOpen = true
	OnPresetSelected()

	System.PlaySound("Play_SFX_NewYou_IntoAndLoop");
end

function Close()
	Sinvironment.Activate(false)
	C.OPTIONS:Show(false)
	C.CUSTOMIZE_OPTIONS:Show(false)
	C.VIEWER_OPTIONS:Show(false)
	g_IsOpen = false

	System.PlaySound("Stop_SFX_NewYou_IntoAndLoop")
	System.PlaySound("Play_UI_Login_Back")
end

function CreateMorphSliders()
	local name, faction, race, sex, id = Player.GetInfo()
	local ranges = Game.GetMorphWeightInfo(race, sex)
	local morphsRanges = {}
	local hasNoExistingMorphs = g_Morphs == nil
	log(tostring(hasNoExistingMorphs))
	g_NumMorphs = #ranges

	if hasNoExistingMorphs then
		g_Morphs = {}
		table.insert(g_Morphs, 0)
	end
	table.insert(morphsRanges, {index=1,min=-1,max=1})
	 
	for i,value in ipairs(ranges) do
		if hasNoExistingMorphs then table.insert(g_Morphs, 0) end
		table.insert(morphsRanges, {index=value.index + 1, min=value.min, max=value.max})
	end

	for i, value in ipairs(C.MORPH_GROUPS) do
		local cat = CreateCategory(value.name)

		for eye,val in ipairs(value.morphs) do
			AddSliderToCategory(cat, morphsRanges[val])
		end

		ToggleCategory(cat, false)
	end
end

-- Abit wasteful but easy and it won't be called often at all
function DestroyCategories()
	for i,val in ipairs(g_MorphCategories) do
		Component.RemoveWidget(val.category)
	end
	g_MorphCategories = {}
end

function CreateSInEnviro()
	local name, faction, race, gender, id = Player.GetInfo()
	local info = Player.GetCharacterInfo()
	local loadout = Player.GetCurrentLoadout()
	g_Gender = info.gender
	log(tostring(info))

	Sinvironment.Activate(true)
	Sinvironment.LoadZone(C.SIN_ZONE)

	g_PlayerMdlId = Sinvironment.CreateModel("local_player")
	Sinvironment.SetCharacterSex(g_PlayerMdlId, info.gender)
	Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "main_armor", 75662)
	Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "head", info.headMain)
	Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "head_accessory_a", info.headAccA)
	Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "head_accessory_b", info.headAccB)
	Sinvironment.LoadCharacterEyes(g_PlayerMdlId, info.eyes)
	Sinvironment.SetModelLOD(g_PlayerMdlId, "local_player")
	Sinvironment.SetCharacterWarpaint(g_PlayerMdlId, loadout.chassis_visuals.warpaint_colors)
	Sinvironment.SetCharacterWarpaint(g_PlayerMdlId, info.visuals.warpaint_colors)

	Sinvironment.SetModelScale(g_PlayerMdlId, 1.0)
	Sinvironment.SetModelOrientation(g_PlayerMdlId, {axis={x=0,y=0,z=1}, angle=180})

	Sinvironment.SetModelPosition(g_PlayerMdlId, {x=0, y=-0.35, z=1.45})

	Sinvironment.EnableMouseFocus(g_PlayerMdlId, true)
	Sinvironment.EnableSelectionHighlight(g_PlayerMdlId, false)

	Callback2.FireAndForget(function()
			--Sinvironment.PlayModelAnimation(g_PlayerMdlId, "Body")
			Sinvironment.PlayModelAnimation(g_PlayerMdlId, "Head")
			SetUiPosition()
			C.CUSTOMIZE_OPTIONS:Show(true)
			C.VIEWER_OPTIONS:Show(true)
		end, nil, 1)


	-- Quite frankly, this is BS :/
	local url = WebCache.MakeUrl("visual_loadouts", id);
	WebCache.Subscribe(url, function(args, err)
		local colors = Game.GetCharacterColorsById(256);
		for i,val in ipairs(colors) do
			if tonumber(val.id) == args[1].eye_color_id then
				info.visuals.warpaint_colors[1].zones.eye_color={ dark = val.dark; light = val.light; }
				if g_PlayerMdlId and Sinvironment.IsValidModel(g_PlayerMdlId) then
					Sinvironment.SetCharacterWarpaint(g_PlayerMdlId, info.visuals.warpaint_colors)
				end
			end
		end
	end, false)
	WebCache.QuickUpdate(url)
end

function SetUiPosition()
	local res = GetScreenRes()
	local headPosLeft = Sinvironment.GetHardpointUIPosition(g_PlayerMdlId, "FX_Head", -0.2, 0.14)
	local headPosRight = Sinvironment.GetHardpointUIPosition(g_PlayerMdlId, "FX_Head", 0.2, 0.14)

	if headPosLeft.yPos > 0 and headPosLeft.yPos < res.height then
		C.CUSTOMIZE_OPTIONS:SetDims("width:_; height:_; top:" .. headPosLeft.yPos .. "; right:" .. headPosLeft.xPos)
		C.VIEWER_OPTIONS:SetDims("width:_; height:_; top:" .. headPosRight.yPos .. "; left:" .. headPosRight.xPos)
	end
end

function GetScreenRes()
	local resolution = System.GetResInfo()
	local screenWidth
	local screenHeight
	local fullScreen = not System.GetCvar("rd.videoMode")

	if fullScreen then
		screenWidth = resolution["fullscreenWidth"]
		screenHeight = resolution["fullscreenHeight"]
	else
		screenWidth = resolution["windowWidth"]
		screenHeight = resolution["windowHeight"]
	end

	return {width=screenWidth, height=screenHeight}
end

function CreateCategory(displayName)
	local id = #g_MorphCategories+1
	local cat = Component.CreateWidget("MorphGroup", C.CUSTOMIZE_OPTIONS)
	cat:GetChild("Category.Header.Text"):SetText(displayName)
	cat:GetChild("Category.Header"):BindEvent("OnSubmit", function()
			OnToggleCategory({id=id})
		end)

	local data = 
	{
		category = cat,
		isOpen = false,
		height = C.CATEGORY_CLOSED_HEIGHT
	}

	table.insert(g_MorphCategories, data)
	return data
end

function ToggleCategory(cat, show)
	local btt = cat.category:GetChild("Category.Header")
	local clipBox = cat.category:GetChild("Category.ClipBox")
	clipBox:Show(show)

	local list = clipBox:GetChild("List")

	if show then
		btt:SetTexture("categoryExpanded")
		btt:SetTextureSelected("categoryExpandedRollover")
	else
		btt:SetTexture("categoryCollapsed")
		btt:SetTextureSelected("categoryCollapsedRollover")
	end

	cat.isOpen = show
	AdjustCategories()
end

function AdjustCategories()
	local yOffset = 0
	for i = 1, #g_MorphCategories do
		local val = g_MorphCategories[i]

		val.category:SetDims(unicode.format("width:_; height:_; top:%f; right:_", yOffset))

		if val.isOpen == true then
			yOffset = yOffset + val.height
		elseif val.isOpen == false then
			yOffset = yOffset + C.CATEGORY_CLOSED_HEIGHT
		end
	end
end

function AddSliderToCategory(cat, info)
	local list = cat.options
	local rowWidget = Component.CreateWidget("Slider", cat.category:GetChild("Category.ClipBox.List"))
	local valueTxt = rowWidget:GetChild("Value")
	local adjuster = rowWidget:GetChild("Adjuster")

	rowWidget:GetChild("Text"):SetText(C.MORPH_NAMES[info.index])
	adjuster:SetPercent(GetPrecentForMorph(g_Morphs[info.index], info))

	local UpdateAdjuster = function(arg)
		local min = info.min * g_DarkSoulsValue
		local max = info.max * g_DarkSoulsValue

		local pct = adjuster:GetPercent()
		local val = min+((math.abs(min) + math.abs(max))*pct)
		g_Morphs[info.index] = val
		valueTxt:SetText(unicode.format("%.0f %%", pct*100))
		C.DEBUG_TXT:SetText(unicode.format("Min: %f Max: %f Current: %f Index: %i", info.min, info.max, val, info.index))
		SetMorphs()
	end
	adjuster:BindEvent("OnStateChanged", UpdateAdjuster)

	-- Reset to default
	rowWidget:GetChild("Reset"):BindEvent("OnSubmit", function(arg)
		adjuster:SetPercent(GetPrecentForMorph(0, info))
		UpdateAdjuster()
		System.PlaySound(C.BUTTON_CLICK_SND)
	end)

	-- Add the sliders height
	cat.height = cat.height + C.SLIDER_HEIGHT
end

function GetPrecentForMorph(val, morphInfo)
	local range = (math.abs(morphInfo.min) + math.abs(morphInfo.max))
	local pct = (val+math.abs(morphInfo.min) / range)
	return pct
end

function SwapCamera(camname)
	local durr = 1
	if C.CAMERAS[camname] then
		local cam = C.CAMERAS[camname]
		Sinvironment.SetCameraFoV(cam.fov)

		g_CurrentCam = _table.copy(cam)
		if g_Gender == "male" then
			g_CurrentCam.aim.z = g_CurrentCam.aim.z+0.1
			g_CurrentCam.pos.z = g_CurrentCam.pos.z+0.1
		end

		Sinvironment.SetManualCamera(g_CurrentCam.pos, g_CurrentCam.aim, durr)
		g_ActiveCamPreset = camname
		g_CurrentCamZoom = C.MIN_ZOOM
	end
end

function SetMorphs()
	if g_PlayerMdlId and Sinvironment.IsValidModel(g_PlayerMdlId) then
		Sinvironment.SetMorphWeights(g_PlayerMdlId, g_Morphs)
	end
end

function SetToDefaults()
	g_ActivePreset.name = "Default"
	g_ActivePreset.index = nil
	OnResetAllDefaults()

	local name, faction, race, gender, id = Player.GetInfo()
	local info = Player.GetCharacterInfo()
	Sinvironment.SetCharacterSex(g_PlayerMdlId, gender)
	Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "head", info.headMain)
end

function AddNewLookPreset()
	ShowTextDialog({
		onYes = function(name)
			if LoadLook(name) then
				Component.GenerateEvent("MY_SYSTEM_MESSAGE", {channel="system", text="A preset with that name already exists!"})
				C.PRESETS:SetSelectedByIndex(1)
				OnPresetSelected()
			else
				SaveLook(name)
				table.insert(g_Presets, name)
				g_ActivePreset.name = name
				g_ActivePreset.index = #g_Presets
				SaveLook(name)
				SavePresets()
				LoadPresets()
			end
		end,
		onNo = function()

		end
	})
end

function LoadAndApplyLook(sel_index)
	local idx = sel_index-1
	local presetName = g_Presets[idx]
	local look = LoadLook(presetName)

	if g_Gender == look.gender then
		-- Force head
		Sinvironment.LoadCharacterComponent(g_PlayerMdlId, "head", look.headID)

		g_Morphs = look.weights
		g_ActivePreset = 
		{
			name = presetName,
			index = idx
		}

		DestroyCategories()
		CreateMorphSliders()
		SetMorphs()
	else
		Component.GenerateEvent("MY_SYSTEM_MESSAGE", {channel="system", text="This preset uses a different gender, you need to swap at a new you first."})
		C.PRESETS:SetSelectedByIndex(1)
		OnPresetSelected()
	end
end

function DoMouseDrag()
	Component.ClearGlobalCursorOverride()
	Component.SetGlobalCursorOverride("sys_grab", true)

	if g_MouseDragCallback == nil then
		g_MouseDragCallback = Callback2.Create()
		g_MouseDragCallback:Bind(UpdateMouseDrag)
		g_MouseDragCallback:Schedule(.01)
	end

	g_ModelRotCycle:Stop()
end

-- Borrowed from the char creation
function UpdateMouseDrag()
	local mouseX,mouseY = Component.GetCursorPos()

	--Determine how much to rotate the model
	local degreesPerSecond = (g_MousePos.x - mouseX) * 2
	if (degreesPerSecond ~= 0) then
		g_modelRotationSpeed = g_modelRotationSpeed + degreesPerSecond;
	else
		-- Reduce rotation speed over time when the mouse isn't being dragged
		g_modelRotationSpeed = g_modelRotationSpeed / 2;
	end

	UpdateModelRotation()

	--update current mouse position
	g_MousePos.x = mouseX;
	g_MousePos.y = mouseY;
	
	if (Component.GetMouseButtonState()) then
		-- Left mouse button still pressed, schedule callback
		g_MouseDragCallback:Reschedule(.01)
	else
		-- Else end mouse drag (rotation will continue to update until it slows to a stop)
		g_MouseDragCallback:Cancel()
		g_MouseDragCallback = nil

		if g_MouseOverModel == true then
			Component.ClearGlobalCursorOverride()
			Component.SetGlobalCursorOverride("sys_hand_open", false)
		else
			Component.ClearGlobalCursorOverride()
		end
	end
end

function UpdateModelRotation()
	-- Integrate rotation angle from the given acceleration and speed	
	local dt = System.GetFrameDuration();
	g_modelRotationSpeed = (g_modelRotationSpeed + g_modelRotationAccel * dt) / (1 + 5 * dt);
	g_modelRotationAngle =  g_modelRotationAngle + g_modelRotationSpeed * dt;
	g_modelRotationAngle = (g_modelRotationAngle + 360) % 360;
	
	if (g_PlayerMdlId) then
		Sinvironment.SetModelOrientation(g_PlayerMdlId, {axis={x=0,y=0,z=1}, angle=g_modelRotationAngle});
	end
	
	-- reschedule the callback until we complete our rotation
	if (math.abs(g_modelRotationAccel) > 0.1 or math.abs(g_modelRotationSpeed) > 0.1) then
		if g_ModelRotateCallback == nil then
			g_ModelRotateCallback = Callback2.Create()
			g_ModelRotateCallback:Bind(UpdateModelRotation)
			g_ModelRotateCallback:Schedule(.001)
		else
			g_ModelRotateCallback:Reschedule(.001)
		end
	else
		if g_ModelRotateCallback ~= nil then
			g_ModelRotateCallback:Cancel()
			g_ModelRotateCallback = nil
		end
	end
end

function ModelLerpTo(angle)
	g_ModelLerpToAngle = angle
	if g_ModelRotCycle then
		g_ModelRotCycle:Run(0.01)
	else
		error("g_ModelRotCycle was nil D:")
	end
end

function ModelLerpDo()
	g_modelRotationAngle = _math.lerp(g_modelRotationAngle, g_ModelLerpToAngle, C.MODEL_LERP_SPEED*System.GetFrameDuration())

	if (g_PlayerMdlId) then
		Sinvironment.SetModelOrientation(g_PlayerMdlId, {axis={x=0,y=0,z=1}, angle=g_modelRotationAngle});
	end

	if math.abs(g_modelRotationAngle - g_ModelLerpToAngle) < 0.5 then
		g_ModelRotCycle:Stop()
	end
end

function SetCameraZoom(zoom)
	g_CurrentCamZoom = _math.clamp(zoom, C.MIN_ZOOM, C.MAX_ZOOM)
	if g_CamZoomCb == nil then
		CameraLerpDo()
	end
end

function CameraLerpDo()
	g_CamZoomCb = nil
	local cam = C.CAMERAS[g_ActiveCamPreset]
	local posTarget = cam.pos
	local aimTarget = cam.aim
	posTarget = Vec3.Lerp(posTarget, aimTarget, g_CurrentCamZoom)

	local f = 1 - 1 / (1 + System.GetFrameDuration() * C.ZOOM_LERP_SPEED)
	g_CurrentCam.pos = Vec3.Lerp(g_CurrentCam.pos, posTarget, f)
	g_CurrentCam.aim = Vec3.Lerp(g_CurrentCam.aim, aimTarget, f)

	if Vec3.Distance(g_CurrentCam.pos, posTarget) > 0.01 or Vec3.Distance(g_CurrentCam.aim, aimTarget) > 0.01 then
		g_CamZoomCb = callback(CameraLerpDo, nil, 0.001);
	end

	Sinvironment.SetManualCamera(g_CurrentCam.pos, g_CurrentCam.aim, 0)
end

function LoadPresets()
	g_Presets = Component.GetSetting(C.MORPH_PRESETS_KEY)

	C.PRESETS:ClearItems()
	C.PRESETS:AddItem("Default")
	if g_Presets then
		for i,val in ipairs(g_Presets) do
			C.PRESETS:AddItem(val)
		end
	end
	C.PRESETS:AddItem("Add New")
end

function SavePresets()
	Component.SaveSetting(C.MORPH_PRESETS_KEY, LoadPresets)
end

function LoadLook(name)
	local saveName = C.MORPH_PRESET_PREFIX..name
	return Component.GetSetting(saveName)
end

function SaveLook(name)
	local saveName = C.MORPH_PRESET_PREFIX..name
	local name, faction, race, gender, id = Player.GetInfo()
	local info = Player.GetCharacterInfo()
	local data =
	{
		gender = gender,
		headID = info.headMain,
		weights = g_Morphs
	}
	Component.SaveSetting(saveName, data)
end

function DeleteLook(name)
	local saveName = C.MORPH_PRESET_PREFIX..name
	Component.SaveSetting(saveName, nil)
end

-- This is all done quickly for now :>
function ShowTextDialog(args)
	local textInput = C.TEXT_INPUT_POPUP:GetChild("InputGroup.TextInput")
	textInput:SetText("")
	textInput:SetFocus()
	SimpleDialog.Display(C.TEXT_INPUT_POPUP)
	SimpleDialog.SetTitle("Preset Name")
	C.TEXT_INPUT_POPUP:Show(true)

	SimpleDialog.AddOption("Ok", function()
		if args.onYes then args.onYes(textInput:GetText()); end
		SimpleDialog.Hide()
	end, {color = "#629E0A"})

	SimpleDialog.AddOption("Cancel", function()
		if args.onNo then args.onNo(); end
		SimpleDialog.Hide()
		C.TEXT_INPUT_POPUP:Show(false)
	end, {color = "#8E0909"})

	SimpleDialog.SetDims("center-x:50%; center-y:50%; width:300; height:150;")
end

function ShowDialog(args)
	SimpleDialog.Display(args.body)
	SimpleDialog.SetTitle("Confirm")

	SimpleDialog.AddOption("Yes", function()
		if args.onYes then args.onYes(); end
		SimpleDialog.Hide();
	end, {color = "#629E0A"})

	SimpleDialog.AddOption("No", function()
		if args.onNo then args.onNo(); end
		SimpleDialog.Hide();
	end, {color = "#8E0909"})

	SimpleDialog.SetDims("center-x:50%; center-y:50%; width:300; height:150;")
end