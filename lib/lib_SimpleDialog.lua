-- A hacked up lib_ErrorDialog


if (SimpleDialog) then
	-- only include once
	return;
end
-- public API
SimpleDialog = {};

require "unicode"
require "lib/lib_Callback2";
require "lib/lib_RoundedPopupWindow";
require "lib/lib_MovablePanel";

-- private API
local OPTION_API = {};

-- private locals
local o_POPUP = nil;	-- PopupWindow.Create
local TEXT_WIDG = nil;
local DIALOG_FRAME = Component.CreateFrame("PanelFrame", "_lib_SimpleDialog");
DIALOG_FRAME:SetDepth(-5);
local OPTIONS_GROUP = Component.CreateWidget('<Group dimensions="bottom:100%-10; height:24; width:100%"/>', DIALOG_FRAME);
local CB2_CleanUp = Callback2.Create();
local o_BUTTONS = {};
local g_OnEscape = nil;		-- handler
local g_restoreInputMode = nil;
local g_FOSTER_ERR = nil;	-- the widget that represents the error, fostered into the window
local AddOption, ArrangeOptions, ResizeWindow; -- functions

-- constants
local DEFAULT_ERROR_BUTTON_COLOR = "#FF8060";
SimpleDialog.CLOSE_OPTION = {label=Component.LookupText("Close"), OnPress=function() SimpleDialog.Hide() end};

function OnExit()
	if (g_OnEscape) then
		g_OnEscape();
	end
	SimpleDialog.Hide();
end

DIALOG_FRAME:Show(false);
DIALOG_FRAME:SetDims("center-x:50%; center-y:50%; width:500; height:300;");
DIALOG_FRAME:BindEvent("OnEscape", OnExit);
DIALOG_FRAME:BindEvent("OnClose", function()
	--Component.SetInputMode(g_restoreInputMode);
	g_restoreInputMode = nil;
end);

function SimpleDialog.Display(err, OnEscape)
	-- unfoster error
	if (g_FOSTER_ERR) then
		--Component.FosterWidget(g_FOSTER_ERR, nil);
		g_FOSTER_ERR = nil;
	end
		
	if (err) then
		CB2_CleanUp:Cancel();
		if (not o_POPUP) then
			o_POPUP = RoundedPopupWindow.Create(DIALOG_FRAME);
			o_POPUP:SetTitle(Component.LookupText("ERROR"));
			
			MovablePanel.ConfigFrame({
				frame = DIALOG_FRAME,
				MOVABLE_PARENT = o_POPUP:GetHeader()
			});
			
			o_POPUP:EnableClose(true, OnExit)	-- creates an 'X' button in the title
			o_POPUP:TintBack("#1B1E1F");
			o_POPUP:GetHeader():GetParent():ParamTo("tint", "#2b333a", 0, 0);
			
			TEXT_WIDG = Component.CreateWidget('<Text dimensions="width:100%; top:0; bottom:100%-40" style="font:Demi_13; halign:center; valign:center; wrap:true; clip:true"/>',
								o_POPUP:GetBody());
			
			assert(not DIALOG_FRAME:IsVisible());
			g_restoreInputMode = Component.GetInputMode();
			--Component.SetInputMode("cursor");
			DIALOG_FRAME:Show(true);
			Component.FosterWidget(OPTIONS_GROUP, o_POPUP:GetBody());
		end
		o_POPUP:Open();
		
		if (type(err) == "string") then
			TEXT_WIDG:SetText(err);
		elseif (Component.IsWidget(err)) then
			TEXT_WIDG:SetText("");
			g_FOSTER_ERR = err;
			Component.FosterWidget(g_FOSTER_ERR, o_POPUP:GetBody());
		end
		g_OnEscape = OnEscape;
		SimpleDialog.ResetOptions();
		o_POPUP:GetHeader():GetParent():SetDims("height:40; left:_; right:_; top:-6");
	else
		SimpleDialog.Hide();
	end
	
	DIALOG_FRAME:SetDims("center-x:50%; center-y:50%; width:500; height:300;");
end

function SimpleDialog.SetTitle(title)
	o_POPUP:SetTitle(title);
end

function SimpleDialog.SetDims(dims)
	DIALOG_FRAME:SetDims(dims);
end

function SimpleDialog.ParseWebError(web_err)
	if (web_err.data) then
		local text = Component.LookupText(web_err.data.code);
		if (not text or text == "") then
			text = web_err.data.message;
		end
		return text;
	elseif (web_err.message) then
		return web_err.message;
	else
		return unicode.format("error %s: %s", tostring(web_err.status or "unknown"), tostring(web_err.message or "unknown"));
	end
end

function SimpleDialog.Hide()
	if (o_POPUP) then
		local dur = RoundedPopupWindow.CLOSE_DUR;
		o_POPUP:Close(dur);
		CB2_CleanUp:Reschedule(dur);
	end
end

function SimpleDialog.AddOption(label, OnPress, args)
	if (type(label) == "table") then
		-- treat this as three params in one
		local params = label;
		AddOption(params.label, params.OnPress, params.args);
	else
		AddOption(label, OnPress, args);
	end
	ArrangeButtons();
	ResizeWindow();
end

function SimpleDialog.ResetOptions()
	for _,BUTTON in ipairs(o_BUTTONS) do
		Component.RemoveWidget(BUTTON)
	end
	o_BUTTONS = {};
end

function SimpleDialog.SetOptions(options)
	SimpleDialog.ResetOptions();	
	assert(type(options) == "table", "options must be a table");
	for i,args in ipairs(options) do
		AddOption(args.label, args.OnPress, args.args);
	end
	ArrangeButtons();
	ResizeWindow();
end

-- local functions

local function CleanUpPopUp()
	if (o_POPUP) then
		o_POPUP:Remove();
		o_POPUP = nil;
		TEXT_WIDG = nil;
		DIALOG_FRAME:Show(false);
		SimpleDialog.ResetOptions();	
	end
end
CB2_CleanUp:Bind(CleanUpPopUp);

function AddOption(label, onPress, args)
	local BUTTON = Component.CreateWidget('<Button name="Button" dimensions="dock:fill" style="font:Demi_10;"/>', OPTIONS_GROUP);
	o_BUTTONS[#o_BUTTONS + 1] = BUTTON;
	BUTTON:SetText(label);
	BUTTON:SetDims("center-x:50%; width:"..(100/#o_BUTTONS).."%");
	BUTTON:Autosize("center");
	BUTTON:SetParam("tint", DEFAULT_ERROR_BUTTON_COLOR);
	if (args) then
		if (args.color) then
			BUTTON:SetParam("tint", args.color);
		end
	end
	BUTTON:BindEvent("OnSubmit", function()
		onPress();
	end);
	return BUTTON;
end

function ArrangeButtons()
	local n = #o_BUTTONS;
	for i=1, n do 
		local BUTTON = o_BUTTONS[i];
		BUTTON:SetDims("center-x:"..(100*i/(n+1)).."%; width:_");
	end
end

function ResizeWindow(dur)
	if( g_FOSTER_ERR ) then
		dur = dur or 0;
		DIALOG_FRAME:SetDims("width:500; center-x:_");
		local textDims = g_FOSTER_ERR:GetBounds(false);
		textDims.width = math.max(textDims.width, #o_BUTTONS * 120);	-- allocate some space for the buttons, too
		DIALOG_FRAME:MoveTo("width:"..(textDims.width+150).."; height:"..(textDims.height+150), dur);
	elseif (TEXT_WIDG) then
		dur = dur or 0;
		DIALOG_FRAME:SetDims("width:500; center-x:_");
		local textDims = TEXT_WIDG:GetTextDims(false);
		textDims.width = math.max(textDims.width, #o_BUTTONS * 120);	-- allocate some space for the buttons, too
		DIALOG_FRAME:MoveTo("width:"..(textDims.width+150).."; height:"..(textDims.height+150), dur);
	end
end
