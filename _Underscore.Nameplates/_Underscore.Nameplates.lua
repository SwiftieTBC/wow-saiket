--[[****************************************************************************
  * _Underscore.Nameplates by Saiket                                           *
  * _Underscore.Nameplates.lua - Skins nameplate frames.                       *
  ****************************************************************************]]


local LibSharedMedia = LibStub( "LibSharedMedia-3.0" );
local _Underscore = _Underscore;
local AddOnName, NS = ...;
_Underscore.Nameplates = NS;

NS.Frame = CreateFrame( "Frame", nil, WorldFrame );
NS.Version = GetAddOnMetadata( AddOnName, "Version" ):match( "^([%d.]+)" );

NS.OptionsCharacter = {
	Version = NS.Version;
};
NS.OptionsCharacterDefault = {
	Version = NS.Version;
	TankMode = false;
};

local Plates = {};
NS.Plates = Plates;
NS.PlatesVisible = {};
NS.TargetOutline = CreateFrame( "Frame" );
NS.TargetUpdater = CreateFrame( "Frame" );

NS.NameFont = CreateFont( "_UnderscoreNameplatesNameFont" );
NS.LevelFont = CreateFont( "_UnderscoreNameplatesLevelFont" );
NS.CastFont = CreateFont( "_UnderscoreNameplatesCastFont" );

local Colors = _Underscore.Colors;

NS.ClassificationUpdateRate = 1;

local BarTexture = LibSharedMedia:Fetch( LibSharedMedia.MediaType.STATUSBAR, _Underscore.MediaBar );

local PlateWidth = 64;
local PlateHeight = 6;
local PlateBorder = 1;
local CastHeight = 24;

local HealthIsGhost = 0.005; -- Health ratios below this are assumed to be ghosts
local DifficultyLevelDifference = 2; -- Hostile mobs this many levels above the player show prominent difficulty colors

local InCombat = false;
local HasTarget = false;

local LibNameplate;




-- Individual plate methods
do
	--- Updates some elements one frame after being shown.
	local function OnUpdate ( self )
		self:SetScript( "OnUpdate", nil );

		local Visual = Plates[ self ];
		Visual.Level:ClearAllPoints();
		Visual.Level:SetPoint( "CENTER", Visual.StatusBackground, 0, 1 );
		if ( not InCombat ) then
			self:SetSize( PlateWidth, PlateHeight );
		end
		NS.VisualClassificationUpdate( Visual, true ); -- Force
	end
	--- Reposition elements when a nameplate gets reused.
	function NS:PlateOnShow ()
		local Visual = Plates[ self ];
		NS.PlatesVisible[ self ] = Visual;

		if ( not self:IsMouseOver() ) then -- Note: Fix for bug where highlights get stuck in default UI
			Visual.Highlight:Hide();
		end
		Visual.Highlight:SetPoint( "TOPLEFT", Visual, -PlateBorder, PlateBorder );
		Visual.Highlight:SetPoint( "BOTTOMRIGHT", Visual, PlateBorder, -PlateBorder );
		Visual.Name:SetAllPoints();
		Visual.ThreatBorder:Hide();
		Visual.ThreatBorder.Threat = nil; -- Reset threat level cache

		if ( self.OnShowForced ) then -- Already delayed by a frame
			self.OnShowForced = nil;
			OnUpdate( self );
		else
			self:SetScript( "OnUpdate", OnUpdate );
		end
	end
end
--- Remove plate from visible list when hidden.
function NS:PlateOnHide ()
	NS.PlatesVisible[ self ] = nil;

	-- Hide target outline if shown
	if ( HasTarget and NS.TargetOutline:GetParent() == self ) then
		NS.TargetOutline:Hide();
		NS.TargetOutline:SetParent( nil );
	end
end

do
	local Threat, ThreatBorder;
	local R, G, B;
	--- Updates threat textures to reflect original plates' textures.
	function NS:VisualThreatUpdate ()
		Threat, ThreatBorder = 0, self.ThreatBorder;
		if ( self.Reaction and self.Reaction <= 4 ) then -- Not friendly
			if ( self.ThreatGlow:IsShown() ) then
				R, G, B = self.ThreatGlow:GetVertexColor();
				if ( R > 0.99 and B < 0.01 ) then -- Not solid white (uninitialized)
					Threat = G > 0.5 and 1 or 2;
				end
			end
			if ( NS.OptionsCharacter.TankMode ) then -- Invert
				Threat = 2 - Threat;
			end
		end

		if ( ThreatBorder.Threat ~= Threat ) then -- Changed
			ThreatBorder.Threat = Threat;
			if ( Threat == 0 ) then -- Low
				ThreatBorder:Hide();
			else
				local Color;
				if ( Threat == 1 ) then -- Medium
					Color = Colors.reaction[ 4 ]; -- Neutral
					ThreatBorder:SetTexCoord( 0, 1, 0, 0.5 );
				else -- High
					Color = Colors.reaction[ 3 ]; -- Unfriendly
					ThreatBorder:SetTexCoord( 0, 1, 0.5, 1 );
				end
				ThreatBorder:SetVertexColor( Color[ 1 ], Color[ 2 ], Color[ 3 ] );
				ThreatBorder:Show();
			end
		end
	end
end
do
	local GetCVarBool = GetCVarBool;
	local floor = floor;
	-- Tree of colors to speed up class lookups
	local ClassColors = {};
	for Class, Color in pairs( RAID_CLASS_COLORS ) do
		-- Round values to account for precision loss in GetVertexColor
		local R, G, B = floor( Color.r * 100 + 0.5 ) / 100, floor( Color.g * 100 + 0.5 ) / 100, floor( Color.b * 100 + 0.5 ) / 100;
		local T = ClassColors;
		if ( not T[ R ] ) then
			T[ R ] = {};
		end
		T = T[ R ];
		if ( not T[ G ] ) then
			T[ G ] = {};
		end
		T = T[ G ];
		assert( not T[ B ], "Duplicate class color." );
		T[ B ] = Class;
	end
	--- @return Reaction ID, Is player, Class token if known.
	local function GetClassification ( R, G, B )
		if ( GetCVarBool( "ShowClassColorInNameplate" ) ) then
			local T = ClassColors[ floor( R * 100 + 0.5 ) / 100 ];
			if ( T ) then
				T = T[ floor( G * 100 + 0.5 ) / 100 ];
				if ( T ) then
					local Class = T[ floor( B * 100 + 0.5 ) / 100 ];
					if ( Class ) then
						return 1, true, Class; -- Hostile player
					end
				end
			end
		end

		if ( R < 0.01 and G > 0.99 and B < 0.01 ) then
			return 8; -- Friendly NPC
		elseif ( R < 0.01 and G < 0.01 and B > 0.99 ) then
			return 8, true; -- Friendly player
		elseif ( R > 0.99 and G > 0.99 and B < 0.01 ) then
			return 4; -- Neutral NPC
		else
			return 1; -- Hostile NPC
		end
	end
	local unpack = unpack;
	local UnitLevel = UnitLevel;
	local MAX_PLAYER_LEVEL = MAX_PLAYER_LEVEL;
	--- Periodically interprets the status bar color for info.
	-- @param Force  Updates status even if health bar color didn't change.
	-- @return True if status updated.
	function NS:VisualClassificationUpdate ( Force )
		local Health = self.Health;
		local R, G, B = Health:GetStatusBarColor();
		if ( Force or Health[ 1 ] ~= R or Health[ 2 ] ~= G or Health[ 3 ] ~= B ) then -- Reaction/classification changed
			Health[ 1 ], Health[ 2 ], Health[ 3 ] = R, G, B; -- Save for future comparison

			self.Reaction, self.IsPlayer, self.Class = GetClassification( R, G, B );
			Health.IsHealerMode = self.Reaction > 4 and self.IsPlayer; -- Friendly player

			-- Health bar color
			local Left, Right = Health.Left, Health.Right;
			if ( Health.IsHealerMode ) then
				-- Color fades based on health
				Left:SetBlendMode( "MOD" );
				Left:SetVertexColor( 1, 1, 1, 0.5 );
				Right:SetBlendMode( "ADD" );
				NS.HealthOnValueChanged( Health, Health:GetValue() );
			else
				Left:SetBlendMode( "ADD" );
				Left:SetVertexColor( unpack( Colors.reaction[ self.Reaction ] ) );
				Left:SetAlpha( 1 );
				Right:SetBlendMode( "ADD" );
				Right:SetVertexColor( 1, 1, 1, 0.1 );
			end

			-- Level text/boss icon
			local LevelText, BossIcon = self.Level, self.BossIcon;
			local Level, LevelPlayer = ( LevelText:GetText() or math.huge ) + 0, UnitLevel( "player" );
			if ( LevelPlayer == MAX_PLAYER_LEVEL
				and Level == MAX_PLAYER_LEVEL
				and not self.StatusBorder:IsShown()
			) then -- Hide level text
				LevelText:SetAlpha( 0 );
				BossIcon:SetAlpha( 0 );
			else
				if ( self.Reaction >= 4 ) then -- Dim friendly/neutral levels
					LevelText:SetAlpha( 0.5 );
					BossIcon:SetAlpha( 0.5 );
					BossIcon:SetTexCoord( 0, 1, 0, 1 );
				else -- Hostile
					LevelText:SetAlpha( 1 );
					BossIcon:SetAlpha( 1 );
					if ( self.Class ) then -- Shrink skull so class icon can be seen
						BossIcon:SetTexCoord( -0.3, 1.3, -0.3, 1.3 );
					else
						BossIcon:SetTexCoord( 0, 1, 0, 1 );
					end
				end
			end

			-- Status background
			local StatusBackground = self.StatusBackground;
			if ( self.Class ) then -- Use class icon
				self.ClassIcon:Show();
				self.ClassIcon:SetTexCoord( unpack( CLASS_ICON_TCOORDS[ self.Class ] ) );
				StatusBackground:SetVertexColor( unpack( Colors.class[ self.Class ] ) );
				StatusBackground:SetAlpha( 1 );
			else
				self.ClassIcon:Hide();

				if ( self.Reaction < 4 and Level >= LevelPlayer + DifficultyLevelDifference ) then -- Use difficulty color
					R, G, B = LevelText:GetTextColor();
					StatusBackground:SetVertexColor( R, G, B, 1 );
				else
					if ( Health.IsHealerMode ) then
						StatusBackground:SetVertexColor( 1, 1, 1 );
					else -- Use reaction color
						StatusBackground:SetVertexColor( Left:GetVertexColor() );
					end
					StatusBackground:SetAlpha( 0.3 );
				end
			end

			return true;
		end
	end
end

do
	local modf = math.modf;
	-- @return Shaded bar color based on health percent.
	local function GetHealthColor ( Percent )
		local C = Colors.HealthSmooth;
		if ( Percent == 1 ) then
			return C[ #C - 2 ], C[ #C - 1 ], C[ #C ], 1;
		elseif ( Percent == 0 ) then
			return C[ 1 ], C[ 2 ], C[ 3 ], 1;
		end

		local Segment, Percent = modf( Percent * ( #C / 3 - 1 ) );
		local Index, Inverse = Segment * 3 + 1, 1 - Percent;

		return C[ Index + 3 ] * Percent + C[ Index ] * Inverse,
			C[ Index + 4 ] * Percent + C[ Index + 1 ] * Inverse,
			C[ Index + 5 ] * Percent + C[ Index + 2 ] * Inverse, 1;
	end
	--- Updates the healer-mode health bar when health changes.
	function NS:HealthOnValueChanged ( Health )
		local _, HealthMax = self:GetMinMaxValues();
		local Percent = HealthMax == 0 and 1 or Health / HealthMax;
		self.Left:SetWidth( Percent * ( PlateWidth - PlateHeight ) );
		if ( self.IsHealerMode ) then
			if ( Percent <= HealthIsGhost ) then -- Ghost or close to it
				local C = Colors.disconnected;
				self.Right:SetVertexColor( C[ 1 ], C[ 2 ], C[ 3 ], 1 );
			else
				self.Right:SetVertexColor( GetHealthColor( Percent ) );
			end
		end
	end
end

do
	--- Repositions the uninterruptibility texture right after being shown.
	local function OnUpdate ( self )
		self:SetScript( "OnUpdate", nil );
		self.NoInterrupt:ClearAllPoints();
		self.NoInterrupt:SetPoint( "CENTER", self.Icon, -1, -2 );
		self.NoInterrupt:SetSize( CastHeight * 3, CastHeight * 3 );
	end
	--- Shows or hides the interrupt immunity shield.
	local function CastOnInterruptibleChanged ( self, Uninterruptible )
		if ( self.Uninterruptible ~= Uninterruptible ) then
			self.Uninterruptible = Uninterruptible;

			-- Gray out bar if uninterruptable
			for _, Texture in ipairs( self ) do
				Texture:SetDesaturated( Uninterruptible );
				if ( Uninterruptible ) then -- Don't shade the desaturated texture
					Texture:SetVertexColor( 1, 1, 1 );
				else -- Use original vertex color
					Texture:SetVertexColor( unpack( Texture ) );
				end
			end
			if ( Uninterruptible ) then -- Use color when grayed out for contrast
				self.Name:SetTextColor( unpack( Colors.Normal ) );
			else
				self.Name:SetTextColor( 1, 1, 1, 1 ); -- Plain white
			end

			local Flash = NS.Flash;
			Flash:StopAnimating();
			if ( not Uninterruptible and UnitCanAttack( "player", "target" ) ) then
				-- Not friendly and spell just became interruptible
				Flash:SetParent( self );
				Flash:SetPoint( "CENTER", -CastHeight / 2, 0 ); -- Account for spell icon on left
				Flash:Show();
				Flash.Animation:Play();
			else
				Flash:Hide();
			end
			self:SetScript( "OnUpdate", OnUpdate );
		end
	end
	--- Reposition elements and adds spell details when a castbar is shown.
	function NS:CastOnShow ()
		self:RegisterEvent( "UNIT_SPELLCAST_INTERRUPTIBLE" );
		self:RegisterEvent( "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" );

		local Name, _, _, _, _, _, _, _, Uninterruptible = UnitCastingInfo( "target" );
		if ( not Name ) then
			Name, _, _, _, _, _, _, Uninterruptible = UnitChannelInfo( "target" );
		end
		self.Name:SetText( Name );

		self:ClearAllPoints();
		self:SetPoint( "TOPLEFT", self.Icon, "TOPRIGHT" );
		self:SetPoint( "BOTTOM", self.Icon, "BOTTOM" );
		self:SetPoint( "RIGHT", self:GetParent(), CastHeight - PlateHeight, 0 );

		CastOnInterruptibleChanged( self, Uninterruptible );
	end
	--- Unregisters events when a castbar hides.
	function NS:CastOnHide ()
		self:UnregisterEvent( "UNIT_SPELLCAST_INTERRUPTIBLE" );
		self:UnregisterEvent( "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" );
		self.Uninterruptible = nil;
		self:Hide(); -- In case parent plate is hidden
	end
	--- Updates the interrupt immunity shield if it changes mid-cast.
	function NS:CastOnEvent ( Event, UnitID )
		if ( UnitID == "target" ) then
			CastOnInterruptibleChanged( self, Event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" );
		end
	end
end




-- Main plate handling and updating
do
	local ThreatBorders = [[Interface\AddOns\]]..AddOnName..[[\Skin\ThreatBorders]];
	--- Adds and skins a new nameplate.
	local function PlateAdd ( Plate )
		if ( LibNameplate and LibNameplate.NameplateFirstLoad ) then
			-- Allow LibNameplate to hook first for compatibility
			LibNameplate:NameplateFirstLoad( Plate );
		end
		local Visual = CreateFrame( "Frame", nil, Plate );
		Plates[ Plate ] = Visual;

		local Health, Cast = Plate:GetChildren();
		Visual.Health, Visual.Cast = Health, Cast;
		local BossIcon, RaidIcon, CastTexture, CastBorder;
		Visual.ThreatGlow, Visual.StatusBackground,
			Visual.Highlight, Visual.Name, Visual.Level,
			Visual.BossIcon, RaidIcon, Visual.StatusBorder = Plate:GetRegions();
		CastTexture, CastBorder, Cast.NoInterrupt, Cast.Icon = Cast:GetRegions();


		Visual:SetSize( PlateWidth, PlateHeight );
		Visual:SetPoint( "BOTTOM" );


		-- Border
		_Underscore.Backdrop.Create( Visual, PlateBorder ):SetParent( Plate ); -- Parent to original nameplate for layering
		Visual.Highlight:SetTexture( [[Interface\QuestFrame\UI-QuestTitleHighlight]] );


		-- Indicator section
		Visual.StatusBackground:SetParent( Visual );
		Visual.StatusBackground:ClearAllPoints();
		Visual.StatusBackground:SetPoint( "TOPLEFT" );
		Visual.StatusBackground:SetPoint( "BOTTOMRIGHT", Visual, "BOTTOMLEFT", PlateHeight, 0 );
		Visual.StatusBackground:SetDrawLayer( "BORDER" );
		Visual.StatusBackground:SetTexture( BarTexture );
		Visual.StatusBackground:SetBlendMode( "ADD" );

		-- Border for status section
		Visual.StatusBorder:SetParent( Visual );
		Visual.StatusBorder:SetDrawLayer( "OVERLAY" );
		Visual.StatusBorder:SetTexture( [[Interface\AchievementFrame\UI-Achievement-IconFrame]] );
		Visual.StatusBorder:SetTexCoord( 0, 0.5625, 0, 0.5625 );
		Visual.StatusBorder:SetAlpha( 0.8 );
		local Padding = PlateHeight * 0.35;
		Visual.StatusBorder:ClearAllPoints();
		Visual.StatusBorder:SetPoint( "TOPRIGHT", Visual.StatusBackground, Padding, Padding );
		Visual.StatusBorder:SetPoint( "BOTTOMLEFT", Visual.StatusBackground, -Padding, -Padding );

		-- Put boss icon inside status border
		Visual.BossIcon:SetParent( Visual );
		Visual.BossIcon:SetAllPoints( Visual.StatusBackground );
		Visual.BossIcon:SetDrawLayer( "ARTWORK" );
		Visual.BossIcon:SetBlendMode( "ADD" );

		-- Level text
		Visual.Level:SetParent( Visual );
		Visual.Level:SetFontObject( NS.LevelFont );

		-- Class icon
		Visual.ClassIcon = Visual:CreateTexture( nil, "ARTWORK" );
		Visual.ClassIcon:SetAllPoints( Visual.StatusBackground );
		Visual.ClassIcon:SetTexture( [[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]] );
		Visual.ClassIcon:SetBlendMode( "ADD" );
		Visual.ClassIcon:SetAlpha( 0.5 );
		Visual.ClassIcon:SetDesaturated( true );


		-- Health bar
		Health:SetStatusBarTexture( "" ); -- Keeps the texture region, but keeps its path value set to nil
		-- Separate filled and empty halves of the statusbar
		Health.Left = Visual:CreateTexture( nil, "ARTWORK" );
		Health.Left:SetPoint( "TOPLEFT", Visual.StatusBackground, "TOPRIGHT" );
		Health.Left:SetPoint( "BOTTOM" );
		Health.Left:SetTexture( BarTexture );
		Health.Right = Visual:CreateTexture( nil, "ARTWORK" );
		Health.Right:SetPoint( "TOPRIGHT" );
		Health.Right:SetPoint( "BOTTOMLEFT", Health.Left, "BOTTOMRIGHT" );
		Health.Right:SetTexture( BarTexture );
		Health:SetScript( "OnValueChanged", NS.HealthOnValueChanged );
		NS.HealthOnValueChanged( Health, Health:GetValue() );

		-- Name text
		local NameContainer = CreateFrame( "Frame", nil, Plate );
		NameContainer:SetPoint( "TOPRIGHT", Health.Right );
		NameContainer:SetPoint( "BOTTOMLEFT", Health.Left, 2, 2 );
		NameContainer:SetAlpha( 0.4 ); -- Prevents default UI from resetting alpha
		Visual.Name:SetParent( NameContainer );
		Visual.Name:SetFontObject( NS.NameFont );


		-- Cast bar
		Cast:SetParent( Visual );
		Cast:SetScript( "OnShow", NS.CastOnShow );
		Cast:SetScript( "OnHide", NS.CastOnHide );
		Cast:SetScript( "OnEvent", NS.CastOnEvent );
		Cast:SetStatusBarTexture( BarTexture );
		CastTexture:SetDrawLayer( "BORDER" );
		-- Register for desaturation on uninterruptible
		Cast[ #Cast + 1 ] = CastTexture;
		CastTexture[ 1 ], CastTexture[ 2 ], CastTexture[ 3 ] = unpack( Colors.Cast );
		-- Icon/icon border
		Cast.Icon:ClearAllPoints();
		Cast.Icon:SetPoint( "BOTTOMRIGHT", Visual.StatusBackground, "TOPRIGHT", 0, 2 );
		Cast.Icon:SetSize( CastHeight, CastHeight );
		_Underscore.SkinButtonIcon( Cast.Icon );
		CastBorder:SetTexture(); -- Seems to cause crashes when attempting to anchor
		local IconBorder = Cast:CreateTexture( nil, "OVERLAY" );
		IconBorder:SetTexture( [[Interface\AchievementFrame\UI-Achievement-IconFrame]] );
		IconBorder:SetTexCoord( 0, 0.5625, 0, 0.5625 );
		local Padding = CastHeight * 0.35;
		IconBorder:SetPoint( "TOPRIGHT", Cast.Icon, Padding, Padding );
		IconBorder:SetPoint( "BOTTOMLEFT", Cast.Icon, -Padding, -Padding );
		Cast[ #Cast + 1 ] = IconBorder;
		IconBorder[ 1 ], IconBorder[ 2 ], IconBorder[ 3 ] = 1, 1, 1;
		-- Bar border/background
		local Background = Cast:CreateTexture( nil, "BACKGROUND" );
		Background:SetAllPoints();
		Background:SetTexture( BarTexture );
		Background:SetBlendMode( "MOD" );
		Background:SetAlpha( 0.5 );
		local BarBorder = Cast:CreateTexture( nil, "ARTWORK" );
		BarBorder:SetPoint( "TOPRIGHT", 4, 8 );
		BarBorder:SetPoint( "BOTTOMLEFT", -4, -8 );
		BarBorder:SetTexture( [[Interface\AchievementFrame\UI-Achievement-ProgressBar-Border]] );
		BarBorder:SetTexCoord( 0, 0.875, 0, 0.75 );
		Cast[ #Cast + 1 ] = BarBorder;
		BarBorder[ 1 ], BarBorder[ 2 ], BarBorder[ 3 ] = 1, 0.9, 0.4; -- Matches color of icon border
		-- Interrupt icon
		Cast.NoInterrupt:SetTexture( [[Interface\AchievementFrame\UI-Achievement-Shields]] );
		Cast.NoInterrupt:SetDrawLayer( "BACKGROUND" );
		Cast.NoInterrupt:SetTexCoord( 1, 0.5, 0, 1 );
		-- Spell name
		Cast.Name = Cast:CreateFontString( nil, "ARTWORK", NS.CastFont:GetName() );
		Cast.Name:SetPoint( "TOPLEFT", 8, -4 );
		Cast.Name:SetPoint( "BOTTOMRIGHT", -4, 4 );
		if ( Cast:IsVisible() ) then
			NS.CastOnShow( Cast );
		end


		-- Misc
		-- Put raid icon above nameplate
		RaidIcon:SetSize( 32, 32 );
		RaidIcon:ClearAllPoints();
		RaidIcon:SetPoint( "BOTTOM", Visual, "TOP" );

		-- Threat
		Visual.ThreatGlow:SetTexture();
		Visual.ThreatBorder = Visual:CreateTexture( nil, "BACKGROUND" );
		Visual.ThreatBorder:SetPoint( "CENTER" );
		Visual.ThreatBorder:SetSize( ( PlateWidth + 2 * PlateBorder ) * 256 / 128, ( PlateHeight + 2 * PlateBorder ) * 32 / 12 );
		Visual.ThreatBorder:SetTexture( ThreatBorders );


		Plate:SetScript( "OnShow", NS.PlateOnShow );
		Plate:SetScript( "OnHide", NS.PlateOnHide );
		if ( Plate:IsVisible() ) then
			Plate.OnShowForced = true; -- Updates all elements without waiting one frame
			NS.PlateOnShow( Plate );
		end
	end

	local select = select;
	--- Scans children of WorldFrame and handles new nameplates.
	local function PlatesScan ( ... )
		for Index = 1, select( "#", ... ) do
			local Frame = select( Index, ... );
			if ( not Plates[ Frame ] ) then
				local Name = Frame:GetName();
				if ( Name and Name:match( "^NamePlate%d+$" ) ) then
					PlateAdd( Frame );
				end
			end
		end
	end

	local ChildCount, NewChildCount = 0;
	local NextUpdate = 0;
	local pairs = pairs;
	--- Periodically scans for new nameplate frames to skin.
	function NS.Frame:OnUpdate ( Elapsed )
		-- Check for new nameplates
		NewChildCount = WorldFrame:GetNumChildren();
		if ( ChildCount ~= NewChildCount ) then
			ChildCount = NewChildCount;

			PlatesScan( WorldFrame:GetChildren() );
		end

		NextUpdate = NextUpdate - Elapsed;
		if ( NextUpdate <= 0 ) then
			NextUpdate = NS.ClassificationUpdateRate;

			for Plate, Visual in pairs( NS.PlatesVisible ) do
				NS.VisualClassificationUpdate( Visual );
			end
		end

		if ( InCombat ) then -- Update threat borders
			for Plate, Visual in pairs( NS.PlatesVisible ) do
				NS.VisualThreatUpdate( Visual );
			end
		end
	end

	local GetAlpha, SetAlpha = NS.Frame.GetAlpha, NS.Frame.SetAlpha;
	--- Keeps the nameplate's alpha set properly, and updates target.
	function NS.TargetUpdater:OnUpdate ()
		for Plate in pairs( NS.PlatesVisible ) do
			if ( GetAlpha( Plate ) == 1 ) then -- Current target
				local TargetOutline = NS.TargetOutline;
				if ( TargetOutline:GetParent() ~= Plate ) then -- Not already positioned
					-- Position outline
					TargetOutline:SetParent( Plate );
					TargetOutline:SetFrameLevel( Plate:GetFrameLevel() );
					TargetOutline:SetPoint( "BOTTOM" );
					TargetOutline:Show();
				end
			else -- Not target
				SetAlpha( Plate, 1 );
			end
		end
	end
end




--- Checks for embeded LibNameplate installs after each mod loads.
function NS.Frame:ADDON_LOADED ( Event )
	local Lib = LibStub( "LibNameplate-1.0", true );
	if ( Lib ) then
		LibNameplate = Lib;
		self:UnregisterEvent( Event );
	end
end
--- Sets CVars to allow threat and class info.
function NS.Frame:VARIABLES_LOADED ( Event )
	self[ Event ] = nil;

	SetCVar( "ThreatWarning", 3 ); -- Always show threat warning glow textures
	SetCVar( "ShowClassColorInNameplate", 1 );
	SetCVar( "nameplateOverlapH", 1 ); -- Keep ends of nameplates from overlapping
end
--- Resize any new nameplates that couldn't be resized in combat.
function NS.Frame:PLAYER_REGEN_ENABLED ()
	InCombat = false;

	for Plate, Visual in pairs( Plates ) do
		Plate:SetSize( PlateWidth, PlateHeight );
	end

	for Plate, Visual in pairs( NS.PlatesVisible ) do
		Visual.ThreatBorder:Hide();
		Visual.ThreatBorder.Threat = nil; -- Reset threat level cache
	end
end
--- Caches combat status when entering a fight.
function NS.Frame:PLAYER_REGEN_DISABLED ()
	InCombat = true;
end
--- Manages the target outline frame when changing targets.
function NS.Frame:PLAYER_TARGET_CHANGED ()
	if ( HasTarget ) then -- Clear previous target indicator
		NS.TargetOutline:Hide();
		NS.TargetOutline:SetParent( nil );
	end
	HasTarget = UnitExists( "target" );

	if ( HasTarget ) then
		NS.TargetUpdater:Show();
	else
		NS.TargetUpdater:Hide();
	end
end




--- Inverts threat display mode for tanks.
-- @return True if setting changed.
function NS.SetTankMode ( Enable )
	if ( NS.OptionsCharacter.TankMode ~= Enable ) then
		NS.OptionsCharacter.TankMode = Enable;
		return true;
	end
end
--- Slash command to set tank threat mode.
function NS.SlashCommand ( Input )
	local Enable = tonumber( SecureCmdOptionParse( Input ) ); -- 1 to enable, 0 to disable
	if ( Enable ) then
		Enable = Enable == 1;
	else
		Enable = not NS.OptionsCharacter.TankMode;
	end

	if ( NS.SetTankMode( Enable ) ) then
		local Color = Enable and GREEN_FONT_COLOR or NORMAL_FONT_COLOR;
		DEFAULT_CHAT_FRAME:AddMessage( NS.L.TANKMODE_FORMAT:format( NS.L[ Enable and "ENABLED" or "DISABLED" ] ),
			Color.r, Color.g, Color.b );
	end
end




--- Loads an options table, or the defaults.
function NS.Synchronize ( OptionsCharacter )
	-- Load defaults if settings omitted
	if ( not OptionsCharacter ) then
		OptionsCharacter = NS.OptionsCharacterDefault;
	end

	NS.SetTankMode( OptionsCharacter.TankMode );
end
--- Loads defaults and validates settings.
function NS.OnLoad ()
	NS.OnLoad = nil;

	local OptionsCharacter = _UnderscoreNameplatesOptionsCharacter;
	_UnderscoreNameplatesOptionsCharacter = NS.OptionsCharacter;

	if ( OptionsCharacter ) then
		OptionsCharacter.Version = NS.Version;
	end

	NS.Synchronize( OptionsCharacter ); -- Loads defaults if nil
end




local Frame = NS.Frame;
Frame:SetScript( "OnEvent", _Underscore.Frame.OnEvent );
Frame:SetScript( "OnUpdate", Frame.OnUpdate );
Frame:RegisterEvent( "ADDON_LOADED" );
Frame:RegisterEvent( "VARIABLES_LOADED" );
if ( IsLoggedIn() ) then
	Frame:VARIABLES_LOADED( "VARIABLES_LOADED" );
end
Frame:RegisterEvent( "PLAYER_REGEN_DISABLED" );
Frame:RegisterEvent( "PLAYER_REGEN_ENABLED" );
Frame:RegisterEvent( "PLAYER_TARGET_CHANGED" );
_Underscore.RegisterAddOnInitializer( AddOnName, NS.OnLoad );


-- Fonts
NS.NameFont:SetFont( [[Fonts\ARIALN.TTF]], 8, "OUTLINE" );
NS.NameFont:SetShadowColor( 0, 0, 0, 0 ); -- Hide shadow
NS.NameFont:SetJustifyV( "MIDDLE" );
NS.NameFont:SetJustifyH( "LEFT" );

NS.LevelFont:SetFont( [[Fonts\ARIALN.TTF]], 6, "OUTLINE" );
NS.LevelFont:SetShadowColor( 0, 0, 0, 1 );
NS.LevelFont:SetShadowOffset( 1.5, -1.5 );

NS.CastFont:SetFont( [[Fonts\ARIALN.TTF]], 14, "OUTLINE" );
NS.CastFont:SetJustifyV( "MIDDLE" );
NS.CastFont:SetJustifyH( "LEFT" );


-- Target outline
NS.TargetOutline:SetSize( PlateWidth, PlateHeight );
local Outline = NS.TargetOutline:CreateTexture( nil, "BORDER" );
Outline:SetTexture( 1, 1, 1 );
Outline:SetPoint( "TOPRIGHT", PlateBorder, PlateBorder );
Outline:SetPoint( "BOTTOMLEFT", -PlateBorder, -PlateBorder );
local Mask = NS.TargetOutline:CreateTexture( nil, "ARTWORK" );
Mask:SetTexture( 0, 0, 0 );
Mask:SetAllPoints();

-- Target outline updater
NS.TargetUpdater:Hide();
NS.TargetUpdater:SetScript( "OnUpdate", NS.TargetUpdater.OnUpdate );
-- Higher frame stratas execute OnUpdates later
NS.TargetUpdater:SetFrameStrata( "TOOLTIP" );


-- Interrupt flash
local Flash = NS.Frame:CreateTexture( nil, "OVERLAY" );
NS.Flash = Flash;
Flash:SetSize( 400 / 300 * ( PlateWidth + 2 * ( CastHeight - PlateHeight ) ), 171 / 70 * CastHeight );
Flash:SetTexture( [[Interface\AchievementFrame\UI-Achievement-Alert-Glow]] );
Flash:SetBlendMode( "ADD" );
Flash:SetTexCoord( 0, 0.78125, 0, 0.66796875 );
Flash:SetAlpha( 0 );
Flash:Hide();
Flash.Animation = Flash:CreateAnimationGroup();
local FadeIn = Flash.Animation:CreateAnimation( "Alpha" );
FadeIn:SetChange( 1.0 );
FadeIn:SetDuration( 0.1 );
local FadeOut = Flash.Animation:CreateAnimation( "Alpha" );
FadeOut:SetOrder( 2 );
FadeOut:SetChange( -1.0 );
FadeOut:SetDuration( 0.3 );


SlashCmdList[ "_UNDERSCORE_NAMEPLATES" ] = NS.SlashCommand;