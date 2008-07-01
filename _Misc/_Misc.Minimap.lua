--[[****************************************************************************
  * _Misc by Saiket                                                            *
  * _Misc.Minimap.lua - Modifies the minimap frame.                            *
  *                                                                            *
  * + Removes the zoom buttons from the minimap and enables the mousewheel.    *
  * + Adds the name of who pings the minimap to the ping itself.               *
  * + Keeps the ping visible for 30 seconds after it appears.                  *
  ****************************************************************************]]


local _Misc = _Misc;
local me = {
	Text = MiniMapPing:CreateFontString( nil, "ARTWORK", "NumberFontNormalSmall" );
};
_Misc.Minimap = me;




--[[****************************************************************************
  * Function: _Misc.Minimap:OnMouseWheel                                       *
  * Description: Zooms the minimap when mousewheeled over.                     *
  ****************************************************************************]]
function me:OnMouseWheel ( Delta )
	self:SetZoom( min( max( self:GetZoom() + Delta, 0 ), 5 ) );
end


--[[****************************************************************************
  * Function: _Misc.Minimap:MiniMapPingOnEvent                                 *
  * Description: Catches the MINIMAP_PING event and displays the name of the   *
  *   player who pinged.                                                       *
  ****************************************************************************]]
function me:MiniMapPingOnEvent ( Event, UnitID )
	if ( Event == "MINIMAP_PING" ) then
		me.Text:SetText( UnitName( UnitID ) );
	end
end




--------------------------------------------------------------------------------
-- Function Hooks / Execution
-----------------------------

do
	MINIMAPPING_TIMER = 30; -- The little minimap blip will remain visible for this number of seconds

	-- Generate the new ping name fontstring
	me.Text:SetPoint( "TOPRIGHT", MiniMapPing, "CENTER", -8, -8 );
	me.Text:SetTextColor( GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, 0.5 ); -- 50% opacity
	-- Hook MINIMAP_PING
	_Misc.HookScript( MiniMapPing, "OnEvent", me.MiniMapPingOnEvent );


	-- Enable scroll wheel
	_Misc.HookScript( Minimap, "OnMouseWheel", me.OnMouseWheel );
	Minimap:EnableMouseWheel( true );

	MinimapZoomIn:Hide();
	MinimapZoomOut:Hide();
end
