--[[****************************************************************************
  * _NPCScan.Overlay by Saiket                                                 *
  * _NPCScan.Overlay.Modules.lua - Manages map modules.                        *
  ****************************************************************************]]


local AddOnName, Overlay = ...;
local me = CreateFrame( "Frame" );
Overlay.Modules = me;


me.AlphaDefault = 0.5;

me.List = {};
local LoadQueue = {};




--- @return Enabled state from options table.
local function GetEnabled ( Options, Name )
	return Options.Modules[ Name ] ~= false; -- Uninitialized (nil) defaults to enabled
end
--- @return Alpha from options table.
local function GetAlpha ( Options, Name )
	return Options.ModulesAlpha[ Name ] or me.List[ Name ].AlphaDefault or me.AlphaDefault;
end


local SafeCall = Overlay.SafeCall;
--- Sets a module's overlay alpha.
local function SetAlpha ( Module, Alpha )
	if ( Module.Enabled and Module.Alpha ~= Alpha ) then
		Module.Alpha = Alpha;
		if ( Module.SetAlpha ) then
			SafeCall( Module.SetAlpha, Module, Alpha );
		end
	end
end
--- Disables a module.
local function Disable ( Module )
	if ( Module.Enabled ) then
		if ( Module.OnDisable ) then
			SafeCall( Module.OnDisable, Module );
		end
		Module.Enabled = nil;
	end
end
--- Enables a module.
local function Enable ( Module )
	if ( Module.Loaded and not Module.Enabled ) then
		Module.Enabled = true;
		if ( Module.OnEnable ) then
			SafeCall( Module.OnEnable, Module );
		end
		SetAlpha( Module, GetAlpha( Overlay.Options, Module.Name ) );
		if ( Module.OnMapUpdate ) then
			SafeCall( Module.OnMapUpdate, Module );
		end
	end
end
--- Shuts a module down and GCs resources created in OnLoad.
local function Unload ( Module )
	if ( Module.Loaded ) then
		Disable( Module );

		if ( Module.OnUnload ) then
			SafeCall( Module.OnUnload, Module );
		end
		Module.Loaded = nil;
	end
	Module.OnLoad, Module.OnUnload = nil;
	Module.OnEnable, Module.OnDisable = nil;
	Module.OnMapUpdate, Module.SetAlpha = nil;
end
--- Loads module and initializes its settings.
local function Load ( Module )
	if ( Module.Registered and not Module.Loaded ) then
		Module.Loaded = true;
		if ( Module.OnLoad ) then
			SafeCall( Module.OnLoad, Module );
			Module.OnLoad = nil;
		end

		if ( me.Synchronized and GetEnabled( Overlay.Options, Module.Name ) ) then
			Enable( Module );
		end
	end
end
--- Unloads all of the module's resources.
local function Unregister ( Module )
	if ( Module.Registered ) then
		Unload( Module );

		if ( Module.OnUnregister ) then
			SafeCall( Module.OnUnregister, Module );
			Module.OnUnregister = nil;
		end

		Module.Registered = nil;
		Module.Config:Unregister();
	end
end
--- Prepares a module to load.
local function Register ( Module, Name, Label, ParentAddOn )
	if ( not Module.Registered ) then
		Module.Registered, Module.Name = true, Name;
		Module.Config = Overlay.Config.ModuleRegister( Module, Label );
		-- No need for an OnRegister handler

		if ( not ParentAddOn or IsAddOnLoaded( ParentAddOn ) ) then
			Load( Module );
		else -- Dependency not loaded
			local Loadable, Reason = select( 5, GetAddOnInfo( ParentAddOn ) );
			if ( Loadable
				or ( Reason == "DISABLED" and IsAddOnLoadOnDemand( ParentAddOn ) ) -- Can be re-enabled
			) then -- Potentially loadable
				LoadQueue[ ParentAddOn:upper() ] = Module;
			else
				Unregister( Module );
			end
		end
	end
end




do
	--- Calls OnMapUpdate for all enabled modules.
	local function UpdateModules ( Map )
		for Name, Module in pairs( me.List ) do
			if ( Module.Enabled and Module.OnMapUpdate ) then
				SafeCall( Module.OnMapUpdate, Module, Map );
			end
		end
	end
	local UpdateAll, UpdateMaps = false, {};
	--- Throttles full map updates to once per frame.
	local function OnUpdate ()
		me:SetScript( "OnUpdate", nil );

		if ( UpdateAll ) then
			UpdateAll = false;
			UpdateModules( nil );
		else
			for Map in pairs( UpdateMaps ) do
				UpdateModules( Map );
				UpdateMaps[ Map ] = nil;
			end
		end
	end
	--- Updates a map for all active modules.
	-- @param Map  MapID to update, or nil to update all maps.
	function me.UpdateMap ( Map )
		if ( not UpdateAll ) then
			if ( Map ) then
				UpdateMaps[ Map ] = true;
			else
				UpdateAll = true;
				wipe( UpdateMaps );
			end
			me:SetScript( "OnUpdate", OnUpdate );
		end
	end
end


--- Registers a canvas module to paint polygons on.
-- @param Name  Name of module used in settings keys, etc.
-- @param Module  Module table containing methods.
-- @param Label  Name displayed in configuration screen.
-- @param ParentAddOn  Optional dependency to wait on to load.
function me.Register ( Name, Module, Label, ParentAddOn )
	me.List[ Name ] = Module;
	Register( Module, Name, Label, ParentAddOn );
end
--- Disables the module for the session and disables its configuration controls.
function me.Unregister ( Name )
	Unregister( me.List[ Name ] );
end


--- Enables a module.
-- @return True if enabled successfully.
function me.Enable ( Name )
	if ( not Overlay.Options.Modules[ Name ] ) then
		Overlay.Options.Modules[ Name ] = true;

		local Module = me.List[ Name ];
		Module.Config:SetEnabled( true );
		Enable( Module );
		return true;
	end
end
--- Disables a module.
-- @return True if disabled successfully.
function me.Disable ( Name )
	if ( GetEnabled( Overlay.Options, Name ) ) then
		Overlay.Options.Modules[ Name ] = false;

		local Module = me.List[ Name ];
		Module.Config:SetEnabled( false );
		Disable( Module );
		return true;
	end
end
--- Sets the module's alpha setting.
-- @return True if changed.
function me.SetAlpha ( Name, Alpha )
	if ( Alpha ~= Overlay.Options.ModulesAlpha[ Name ] ) then
		Overlay.Options.ModulesAlpha[ Name ] = Alpha;

		local Module = me.List[ Name ];
		Module.Config.Alpha:SetValue( Alpha );
		SetAlpha( Module, Alpha );
		return true;
	end
end




--- Loads modules that depend on other mods as they load.
function me:ADDON_LOADED ( _, ParentAddOn )
	ParentAddOn = ParentAddOn:upper();
	local Module = LoadQueue[ ParentAddOn ];
	if ( Module ) then
		LoadQueue[ ParentAddOn ] = nil;

		if ( Module.Registered ) then -- Not unregistered
			Load( Module );
		end
	end
end
--- Common event handler.
function me:OnEvent ( Event, ... )
	if ( self[ Event ] ) then
		return self[ Event ]( self, Event, ... );
	end
end
do
	local OptionsExtraDefault = {};
	--- Synchronizes settings of all modules.
	function me.OnSynchronize ( Options )
		me.Synchronized = true;
		-- Preserve options for missing modules
		for Name, Enabled in pairs( Options.Modules ) do
			if ( not me.List[ Name ] ) then
				Overlay.Options.Modules[ Name ] = Enabled;
				Overlay.Options.ModulesAlpha[ Name ] = Options.ModulesAlpha[ Name ];
			end
		end

		-- Synchronize extra module options
		for Name, Module in pairs( me.List ) do
			me[ GetEnabled( Options, Name ) and "Enable" or "Disable" ]( Name );
			me.SetAlpha( Name, GetAlpha( Options, Name ) );

			if ( Module.OnSynchronize ) then
				if ( not Overlay.Options.ModulesExtra[ Name ] ) then
					Overlay.Options.ModulesExtra[ Name ] = {};
				end
				SafeCall( Module.OnSynchronize, Module, Options.ModulesExtra[ Name ] or OptionsExtraDefault );
			end
		end
		for Name, Extra in pairs( Options.ModulesExtra ) do
			if ( not me.List[ Name ] ) then
				Overlay.Options.ModulesExtra[ Name ] = CopyTable( Extra );
			end
		end
	end
end




me:SetScript( "OnEvent", me.OnEvent );
me:RegisterEvent( "ADDON_LOADED" );