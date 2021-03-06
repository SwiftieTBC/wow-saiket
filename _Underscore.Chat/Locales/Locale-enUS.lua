--[[****************************************************************************
  * _Underscore.Chat by Saiket                                                 *
  * Locales/Locale-enUS.lua - Localized string constants (en-US).              *
  ****************************************************************************]]


select( 2, ... ).L = setmetatable( {
	MAXLINES_PRESERVED = "_|cffcccc88Underscore|r.Chat: Chat frame MaxLines preserved for debugging.";

	TIMESTAMP_FORMAT = "|cff808080[%02d:%02d:%02d]|r %s"; -- Hour, Minute, Second, Message
	TIMESTAMP_PATTERN = "^|cff808080%[%d%d:%d%d:%d%d%]|r ";

	URL_FORMAT = " |cffffff9a|Hurl:%s|h<%1$s>|h|r ";
	URLPATH_FORMAT = " |cffffff9a|Hurl:%s%s|h<%1$s%2$s>|h|r "; -- Domain, Path

	RAIDWARNING_FORMAT = "[|cff%02X%02X%02X%s|r]: %s"; -- R, G, B, Author, Message
}, getmetatable( _Underscore.L ) );


-- Chat message formats
CHAT_BATTLEGROUND_GET = "|Hchannel:BATTLEGROUND|h[B]|h %s: ";
CHAT_BATTLEGROUND_LEADER_GET = [[|Hchannel:BATTLEGROUND|h[B|TInterface\GroupFrame\UI-Group-LeaderIcon:0|t]|h %s: ]];
CHAT_GUILD_GET = "|Hchannel:GUILD|h[G]|h %s: ";
CHAT_OFFICER_GET = "|Hchannel:OFFICER|h[O]|h %s: ";
CHAT_PARTY_GET = "|Hchannel:PARTY|h[P]|h %s: ";
CHAT_PARTY_LEADER_GET = [[|Hchannel:PARTY|h[P|TInterface\GroupFrame\UI-Group-LeaderIcon:0|t]|h %s: ]];
CHAT_PARTY_GUIDE_GET = CHAT_PARTY_LEADER_GET;
CHAT_RAID_GET = "|Hchannel:RAID|h[R]|h %s: ";
CHAT_RAID_LEADER_GET = [[|Hchannel:RAID|h[R|TInterface\GroupFrame\UI-Group-LeaderIcon:0|t]|h %s: ]];
CHAT_RAID_WARNING_GET = "|Hchannel:RW|h[R-WARN]|h %s: ";
CHAT_SAY_GET = "|Hchannel:SAY|h[S]|h %s: ";
CHAT_WHISPER_GET = "[W] %s: ";
CHAT_WHISPER_INFORM_GET = "[W]»%s: ";
CHAT_YELL_GET = "|Hchannel:YELL|h[Y]|h %s: ";

CHAT_MONSTER_PARTY_GET   = CHAT_PARTY_GET;
CHAT_MONSTER_SAY_GET     = CHAT_SAY_GET;
CHAT_MONSTER_WHISPER_GET = CHAT_WHISPER_GET;
CHAT_MONSTER_YELL_GET    = CHAT_YELL_GET;