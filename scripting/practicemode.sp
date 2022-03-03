#define UPDATE_URL "https://dl.whiffcity.com/plugins/practicemode/practicemode.txt"

#include <clientprefs>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>
#define DEBUG
#include <vector>

#undef REQUIRE_PLUGIN
#include "botmimic.inc"
#include "csutils.inc"
#include "menu-stocks.inc"

#include <get5>
#include <pugsetup>
#include "include/updater.inc"

#include "practicemode.inc"
#include "restorecvars.inc"
#include "practicemode/util.sp"

#pragma semicolon 1
#pragma newdecls required

#define MAX_PASSWORD_LENGTH 32

bool g_InPracticeMode = false;
bool g_WaitForServerPassword = false;
bool g_PugsetupLoaded = false;
bool g_CSUtilsLoaded = false;
bool g_BotMimicLoaded = false;

// These data structures maintain a list of settings for a toggle-able option:
// the name, the cvar/value for the enabled option, and the cvar/value for the disabled option.
// Note: the first set of values for these data structures is the overall-practice mode cvars,
// which aren't toggle-able or named.
ArrayList g_BinaryOptionIds;
ArrayList g_BinaryOptionNames;
ArrayList g_BinaryOptionEnabled;
ArrayList g_BinaryOptionChangeable;
ArrayList g_BinaryOptionEnabledCvars;
ArrayList g_BinaryOptionEnabledValues;
ArrayList g_BinaryOptionDisabledCvars;
ArrayList g_BinaryOptionDisabledValues;
ArrayList g_BinaryOptionCvarRestore;

ArrayList g_MapList;

/** Chat aliases loaded **/
#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

Handle HTM;
// Plugin cvars
ConVar g_AutostartCvar;
ConVar g_BotRespawnTimeCvar;
ConVar g_DryRunFreezeTimeCvar;
ConVar g_MaxHistorySizeCvar;
ConVar g_PracModeCanBeStartedCvar;
ConVar g_SharedAllNadesCvar;
ConVar g_MaxPlacedBotsCvar;

// Infinite money data
ConVar g_InfiniteMoneyCvar;
// Client cvars cached
int g_ClientColors[MAXPLAYERS + 1][4];
float g_ClientVolume[MAXPLAYERS + 1];

// Grenade trajectory fix data
int g_PredictTrail = -1;
int g_BeamSprite = -1;
ConVar g_PatchGrenadeTrajectoryCvar;
ConVar g_GrenadeTrajectoryClientColorCvar;
ConVar g_RandomGrenadeTrajectoryCvar;

ConVar g_AllowNoclipCvar;
ConVar g_GlowPMBotsCvar;
ConVar g_HoloSpawnsCvar;
ConVar g_GrenadeTrajectoryCvar;
ConVar g_GrenadeThicknessCvar;
ConVar g_GrenadeTimeCvar;
ConVar g_GrenadeSpecTimeCvar;

// Other cvars.
ConVar g_FlashEffectiveThresholdCvar;
ConVar g_TestFlashTeleportDelayCvar;
ConVar g_VersionCvar;

// Saved grenade locations data
#define MAX_GRENADE_SAVES_PLAYER 512
#define GRENADE_EXECUTION_LENGTH 256
// #define GRENADE_DESCRIPTION_LENGTH 256
#define GRENADE_NAME_LENGTH 64
#define GRENADE_ID_LENGTH 16
#define GRENADE_CATEGORY_LENGTH 128
#define GRENADE_DETONATION_KEY_AUTH "auth"
#define GRENADE_DETONATION_KEY_ID "id"
#define GRENADE_DETONATION_KEY_ENTITY "entity"
#define AUTH_LENGTH 64
#define AUTH_METHOD AuthId_Steam2
#define GRENADE_CODE_LENGTH 256

bool g_WaitForSaveNade[MAXPLAYERS + 1] = {false, ...};
char g_GrenadeLocationsFile[PLATFORM_MAX_PATH];
KeyValues
    g_GrenadeLocationsKv;  // Inside any global function, we expect this to be at the root level.
int g_CurrentSavedGrenadeId[MAXPLAYERS + 1];
bool g_UpdatedGrenadeKv = false;  // whether there has been any changed the kv structure this map
int g_NextID = 0;
int g_currentReplayGrenade = -1;

// Grenade Holograms
ArrayList g_EnabledHoloNadeAuth = null;
bool g_HoloNadeLoadDefault = false;
bool g_HoloNadeClientEnabled[MAXPLAYERS + 1];
bool g_HoloNadeClientAllowed[MAXPLAYERS + 1];
int g_HoloNadeClientWhitelist[MAXPLAYERS + 1];

// Grenade history data
int g_GrenadeHistoryIndex[MAXPLAYERS + 1];

ArrayList g_GrenadeHistoryPositions[MAXPLAYERS + 1];
ArrayList g_GrenadeHistoryAngles[MAXPLAYERS + 1];

ArrayList g_ClientGrenadeThrowTimes[MAXPLAYERS + 1];  // ArrayList of <int:entity, float:throw time>
                                                      // pairs of live grenades
bool g_TestingFlash[MAXPLAYERS + 1];
float g_TestingFlashOrigins[MAXPLAYERS + 1][3];
float g_TestingFlashAngles[MAXPLAYERS + 1][3];

bool g_ClientNoFlash[MAXPLAYERS + 1];
float g_LastFlashDetonateTime[MAXPLAYERS + 1];

bool g_RunningRepeatedCommand[MAXPLAYERS + 1];
char g_RunningRepeatedCommandArg[MAXPLAYERS + 1][256];

ArrayList g_RunningRoundRepeatedCommandDelay[MAXPLAYERS + 1]; /* float */
ArrayList g_RunningRoundRepeatedCommandArg[MAXPLAYERS + 1];   /* char[256] */

#define MAX_SIM_REPLAY_NADES 40

GrenadeType g_LastGrenadeType[MAXPLAYERS + 1];
int g_ClientPulledPinButtons[MAXPLAYERS + 1];
bool g_ClientPulledPin[MAXPLAYERS + 1] = {false, ...};
float g_LastGrenadePinPulledOrigin[MAXPLAYERS + 1][3];
float g_LastGrenadePinPulledAngles[MAXPLAYERS + 1][3];
float g_LastGrenadeOrigin[MAXPLAYERS + 1][3];
float g_LastGrenadeVelocity[MAXPLAYERS + 1][3];
float g_LastGrenadeDetonationOrigin[MAXPLAYERS + 1][3];
float g_ClientReplayGrenadeThrowTime[MAX_SIM_REPLAY_NADES];
float g_TiempoRecorrido[MAX_SIM_REPLAY_NADES] = {0.0, ...};
Handle ExplodeNadeTimer[MAX_SIM_REPLAY_NADES] = {INVALID_HANDLE, ...};
#define GRENADE_DETONATE_FLASH_TIME 1.658
#define GRENADE_DETONATE_MOLOTOV_TIME 1.96
float g_ReplayGrenadeLastPausedTime = -1.0;
float g_ReplayGrenadeLastResumedTime[MAX_SIM_REPLAY_NADES] = {-1.0, ...};
float g_ReplayGrenadeLastLastResumedTime[MAX_SIM_REPLAY_NADES] ={ -1.0, ...};
int g_LastGrenadeEntity[MAXPLAYERS + 1];


ArrayList g_GrenadeDetonationSaveQueue; 
#define GRENADE_DETONATION_FIX_PHASE_BREAKGLASS 3
#define GRENADE_DETONATION_FIX_PHASE_SMOKES 2
#define GRENADE_DETONATION_FIX_PHASE_NONSMOKES 1
#define GRENADE_DETONATION_FIX_PHASE_DONE 0
StringMap g_ManagedGrenadeDetonationsToFix;
int g_ManagedGrenadeDetonationsToFixPhase = GRENADE_DETONATION_FIX_PHASE_DONE;

// Respawn values set by clients in the current session
bool g_SavedRespawnActive[MAXPLAYERS + 1];
float g_SavedRespawnOrigin[MAXPLAYERS + 1][3];
float g_SavedRespawnAngles[MAXPLAYERS + 1][3];

char nadelist[128] = "weapon_hegrenade weapon_smokegrenade weapon_flashbang weapon_incgrenade weapon_tagrenade weapon_molotov weapon_decoy";

ArrayList g_ClientBots[MAXPLAYERS + 1];  // Bots owned by each client.
char g_PMBotStartName[MAXPLAYERS + 1][MAX_NAME_LENGTH]; // Used for kicking them, otherwise they rejoin
bool g_IsPMBot[MAXPLAYERS + 1];
float g_BotSpawnOrigin[MAXPLAYERS + 1][3];
int g_BotPlayerModels[MAXPLAYERS + 1] = {-1, ...};
int g_BotPlayerModelsIndex[MAXPLAYERS + 1] = {-1, ...};
float g_BotSpawnAngles[MAXPLAYERS + 1][3];
char g_BotSpawnWeapon[MAXPLAYERS + 1][64];
bool g_BotCrouch[MAXPLAYERS + 1];
bool g_BotJump[MAXPLAYERS + 1];
int g_CurrentBotControl[MAXPLAYERS + 1] = {-1, ...};
int g_BotMindControlOwner[MAXPLAYERS + 1] = {-1, ...};
int g_BotNameNumber[MAXPLAYERS + 1];
float g_BotDeathTime[MAXPLAYERS + 1];

bool g_BotReplayInit = false;
bool g_InBotReplayMode = false;
KeyValues g_ReplaysKv;

bool versusMode, pauseMode;

#define PLAYER_HEIGHT 72.0
#define CROUCH_PLAYER_HEIGHT (PLAYER_HEIGHT - 18.0)
#define CLASS_LENGTH 64

const int kMaxBackupsPerMap = 50;

// These must match the values used by cl_color.
enum ClientColor {
  ClientColor_Yellow = 0,
  ClientColor_Purple = 1,
  ClientColor_Green = 2,
  ClientColor_Blue = 3,
  ClientColor_Orange = 4,
};

int g_LastNoclipCommand[MAXPLAYERS + 1];

// Timer data. Supports 3 modes:
enum TimerType {
  TimerType_Increasing_Movement = 0,  // Increasing timer, begins when client moves.
  TimerType_Increasing_Manual = 1,    // Increasing timer, begins as soon as command is run.
  TimerType_Countdown_Movement = 2,   // Countdown, begins when client moves.
};

bool g_RunningTimeCommand[MAXPLAYERS + 1];
bool g_RunningLiveTimeCommand[MAXPLAYERS + 1];  // Used by .timer2 & .countdown, gets set to true
                                                // when the client begins moving.
float g_TimerDuration[MAXPLAYERS + 1];  // Used by .countdown, set to the length of the countdown.
TimerType g_TimerType[MAXPLAYERS + 1];
float g_LastTimeCommand[MAXPLAYERS + 1];

MoveType g_PreFastForwardMoveTypes[MAXPLAYERS + 1];

enum GrenadeMenuType {
  GrenadeMenuType_NadeGroup = 0,
  GrenadeMenuType_TypeFilter = 1
};

GrenadeType g_ClientLastMenuGrenadeTypeFilter[MAXPLAYERS + 1] = {GrenadeType_None, ...};
GrenadeMenuType g_ClientLastMenuType[MAXPLAYERS + 1];

// Data storing spawn priorities.
ArrayList g_Spawns = null;

enum UserSetting {
  UserSetting_ShowAirtime,
  UserSetting_LeaveNadeMenuOpen,
  UserSetting_NoGrenadeTrajectory,
  UserSetting_SwitchToNadeOnSelect,
  UserSetting_StopsRecordingInspectKey,
  UserSetting_NumSettings,
};
#define USERSETTING_DISPLAY_LENGTH 128
Handle g_UserSettingCookies[UserSetting_NumSettings];
bool g_UserSettingDefaults[UserSetting_NumSettings];
char g_UserSettingDisplayName[UserSetting_NumSettings][USERSETTING_DISPLAY_LENGTH];

// Forwards
Handle g_OnGrenadeSaved = INVALID_HANDLE;
Handle g_OnPracticeModeDisabled = INVALID_HANDLE;
Handle g_OnPracticeModeEnabled = INVALID_HANDLE;
Handle g_OnPracticeModeSettingChanged = INVALID_HANDLE;
Handle g_OnPracticeModeSettingsRead = INVALID_HANDLE;

#define CHICKEN_MODEL "models/chicken/chicken.mdl"

#include "practicemode/grenade_iterators.sp"

//#include "practicemode/demoreplay.sp"

#include "practicemode/botreplay.sp"
#include "practicemode/botreplay_data.sp"
#include "practicemode/botreplay_editor.sp"
#include "practicemode/botreplay_utils.sp"

#include "practicemode/backups.sp"
#include "practicemode/bots.sp"
#include "practicemode/bots_menu.sp"
#include "practicemode/commands.sp"
#include "practicemode/debug.sp"
#include "practicemode/grenade_commands.sp"
#include "practicemode/grenade_filters.sp"
#include "practicemode/grenade_menus.sp"
#include "practicemode/grenade_utils.sp"
#include "practicemode/grenade_accuracy.sp"
#include "practicemode/grenade_hologram.sp"
#include "practicemode/grenade_prediction.sp"
#include "practicemode/learn.sp"
#include "practicemode/natives.sp"
#include "practicemode/pugsetup_integration.sp"
#include "practicemode/settings_menu.sp"
#include "practicemode/spawns.sp"

// clang-format off
public Plugin myinfo = {
  name = "CS:GO PracticeMode",
  author = "splewis",
  description = "A practice mode that can be launched through the .setup menu",
  version = PLUGIN_VERSION,
  url = "https://github.com/splewis/csgo-practice-mode"
};
// clang-format on

public void OnPluginStart() {
  LoadTranslations("common.phrases"); 
  g_InPracticeMode = false;
  AddCommandListener(Command_TeamJoin, "jointeam");
  AddCommandListener(Command_Noclip, "noclip");
  AddCommandListener(Command_SetPos, "setpos");
  AddCommandListener(ChatListener, "say");
  AddCommandListener(ChatListener, "say2");
  AddCommandListener(ChatListener, "say_team");

  // Forwards
  g_OnGrenadeSaved = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Event, Param_Cell,
                                         Param_Array, Param_Array, Param_String);
  g_OnPracticeModeDisabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
  g_OnPracticeModeEnabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
  g_OnPracticeModeSettingChanged = CreateGlobalForward(
      "PM_OnPracticeModeEnabled", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
  g_OnPracticeModeSettingsRead = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);

  // Init data structures to be read from the config file
  g_BinaryOptionIds = new ArrayList(OPTION_NAME_LENGTH);
  g_BinaryOptionNames = new ArrayList(OPTION_NAME_LENGTH);
  g_BinaryOptionEnabled = new ArrayList();
  g_BinaryOptionChangeable = new ArrayList();
  g_BinaryOptionEnabledCvars = new ArrayList();
  g_BinaryOptionEnabledValues = new ArrayList();
  g_BinaryOptionDisabledCvars = new ArrayList();
  g_BinaryOptionDisabledValues = new ArrayList();
  g_BinaryOptionCvarRestore = new ArrayList();
  g_MapList = new ArrayList(PLATFORM_MAX_PATH + 1);
  ReadPracticeSettings();

  // Setup stuff for grenade history
  HookEvent("weapon_fire", Event_WeaponFired);
  HookEvent("flashbang_detonate", Event_FlashDetonate);
  HookEvent("smokegrenade_detonate", Event_SmokeDetonate);
  HookEvent("hegrenade_detonate", Event_SmokeDetonate);
  HookEvent("decoy_started", Event_SmokeDetonate);
  HookEvent("player_blind", Event_PlayerBlind);

  for (int i = 0; i <= MAXPLAYERS; i++) {
    g_GrenadeHistoryPositions[i] = new ArrayList(3);
    g_GrenadeHistoryAngles[i] = new ArrayList(3);
    g_ClientGrenadeThrowTimes[i] = new ArrayList(2);
    g_ClientBots[i] = new ArrayList();
    g_RunningRoundRepeatedCommandArg[i] = new ArrayList(256);
    g_RunningRoundRepeatedCommandDelay[i] = new ArrayList();
  }

  {
    RegAdminCmd("sm_prac", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP, "Lanza Modo Practica");
    RegAdminCmd("sm_launchpractice", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP,
                "Lanzar Modo Practica");
    RegAdminCmd("sm_practice", Command_LaunchPracticeMode, ADMFLAG_CHANGEMAP,
                "Lanzar Modo Practica");
    PM_AddChatAlias(".prac", "sm_prac");

    RegAdminCmd(
        "practicemode_debuginfo", Command_DebugInfo, ADMFLAG_CHANGEMAP,
        "Dumps debug info to a file (addons/sourcemod/logs/practicemode_debuginfo.txt by default)");
    
    RegConsoleCmd("sm_practicesetup", Command_GivePracticeSetupMenu);
    PM_AddChatAlias(".setup", "sm_practicesetup");

    RegConsoleCmd("sm_practicemap", Command_Map);
    PM_AddChatAlias(".map", "sm_practicemap");

    RegConsoleCmd("sm_helpinfo", Command_GiveHelpInfo);
    PM_AddChatAlias(".help", "sm_helpinfo");
  }

  RegAdminCmd("sm_exitpractice", Command_ExitPracticeMode, ADMFLAG_CHANGEMAP,
              "Salir del modo practica");
  // RegAdminCmd("sm_translategrenades", Command_TranslateGrenades, ADMFLAG_CHANGEMAP,
  //             "Traduce todas las granadas de este mapa");
  RegAdminCmd("sm_fixgrenades", Command_FixGrenades, ADMFLAG_CHANGEMAP,
              "Reinicia las ids de las granadas para que sean consecutivas y empieza en 1.");
  RegAdminCmd("sm_fixdetonations", Command_FixGrenadeDetonations, ADMFLAG_CHANGEMAP,
              "Tira todas las granadas y graba la data de detonación.");

  // Grenade history commands
  {
    RegConsoleCmd("sm_grenadeback", Command_GrenadeBack);
    PM_AddChatAlias(".back", "sm_grenadeback");

    RegConsoleCmd("sm_grenadeforward", Command_GrenadeForward);
    PM_AddChatAlias(".forward", "sm_grenadeforward");

    RegConsoleCmd("sm_lastgrenade", Command_LastGrenade);
    PM_AddChatAlias(".last", "sm_lastgrenade");
  }

  // csutils powered nade stuff.
  {
    RegConsoleCmd("sm_throw", Command_Throw);
    PM_AddChatAlias(".throw", "sm_throw");
    PM_AddChatAlias(".rethrow", "sm_throw");
  }

  // Bot commands
  {
    RegConsoleCmd("sm_removeallbots", Command_RemoveAllBots);
    PM_AddChatAlias(".nobots", "sm_removeallbots");

    RegConsoleCmd("sm_botsmenu", Command_BotsMenu);
    PM_AddChatAlias(".bots", "sm_botsmenu");

    RegConsoleCmd("sm_prueba", FUNCION_PRUEBA);
  }

  // Bot replay commands
  {
    RegConsoleCmd("sm_replay", Command_Replay);
    PM_AddChatAlias(".replay", "sm_replay");

    RegConsoleCmd("sm_replays", Command_Replays);
    PM_AddChatAlias(".replays", "sm_replays");

    RegConsoleCmd("sm_replaymode", CommandToggleReplayMode);
    PM_AddChatAlias(".versus", "sm_replaymode");
    PM_AddChatAlias(".replaymode", "sm_replaymode");

    RegConsoleCmd("sm_pausemode", CommandTogglePauseMode);
    PM_AddChatAlias(".pause", "sm_pausemode");

    RegConsoleCmd("sm_namereplay", Command_NameReplay);
    PM_AddChatAlias(".namereplay", "sm_namereplay");

    RegConsoleCmd("sm_namerole", Command_NameRole);
    PM_AddChatAlias(".namerole", "sm_namerole");

    RegConsoleCmd("sm_cancel", Command_Cancel);
    PM_AddChatAlias(".cancel", "sm_cancel");

    RegConsoleCmd("sm_finishrecording", Command_FinishRecording);
    PM_AddChatAlias(".finish", "sm_finishrecording");

    RegConsoleCmd("sm_playrecording", Command_PlayRecording);
    PM_AddChatAlias(".play", "sm_playrecording");
  }

  // Saved grenade location commands
  {

    RegConsoleCmd("sm_savenade", Command_SaveNade);
    PM_AddChatAlias(".save", "sm_savenade");

    RegConsoleCmd("sm_savenadecode", Command_ImportNade);
    PM_AddChatAlias(".import", "sm_savenadecode");

    // RegConsoleCmd("sm_savedelay", Command_SetDelay);
    // PM_AddChatAlias(".setdelay", "sm_savedelay");

    RegConsoleCmd("sm_copylastplayer", Command_CopyPlayerLastGrenade);
    PM_AddChatAlias(".copy", "sm_copylastplayer");
  }

  // spawns commands
  {
    RegConsoleCmd("sm_spec", Command_Spec);
    PM_AddChatAlias(".spec", "sm_spec");

    RegConsoleCmd("sm_joint", Command_JoinT);
    PM_AddChatAlias(".t", "sm_joint");

    RegConsoleCmd("sm_joinct", Command_JoinCT);
    PM_AddChatAlias(".ct", "sm_joinct");

    RegConsoleCmd("sm_respawn", Command_Respawn);
    PM_AddChatAlias(".respawn", "sm_respawn");

    RegConsoleCmd("sm_stoprespawn", Command_StopRespawn);
    PM_AddChatAlias(".stoprespawn", "sm_stoprespawn");
  }

  // Learn commands
  {
    // RegConsoleCmd("sm_learn", Command_Learn);
    // PM_AddChatAlias(".learn", "sm_learn");

    // RegConsoleCmd("sm_skip", Command_Skip);
    // PM_AddChatAlias(".skip", "sm_skip");

    // RegConsoleCmd("sm_stoplearn", Command_StopLearn);
    // PM_AddChatAlias(".stoplearn", "sm_stoplearn");
    // PM_AddChatAlias(".stoplearning", "sm_stoplearn");
    
    // RegConsoleCmd("sm_show", Command_Show);
    // PM_AddChatAlias(".show", "sm_show");
  }

  // Other commands
  {
    RegConsoleCmd("sm_testflash", Command_TestFlash);
    PM_AddChatAlias(".flash", "sm_testflash");
    PM_AddChatAlias(".testflash", "sm_testflash");

    RegConsoleCmd("sm_noflash", Command_NoFlash);
    PM_AddChatAlias(".noflash", "sm_noflash");

    // TODO: A timer menu may be more accesible to users, as the number of timer types continues to
    // increase...
    RegConsoleCmd("sm_time", Command_Time);
    PM_AddChatAlias(".timer", "sm_time");
    PM_AddChatAlias(".time", "sm_time");

    RegConsoleCmd("sm_time2", Command_Time2);
    PM_AddChatAlias(".timer2", "sm_time2");

    RegConsoleCmd("sm_countdown", Command_CountDown);
    PM_AddChatAlias(".countdown", "sm_countdown");

    RegConsoleCmd("sm_clearmap", Command_ClearNades);
    PM_AddChatAlias(".clear", "sm_clearmap");

    // RegConsoleCmd("sm_pmsettings", Command_Settings);
    // PM_AddChatAlias(".settings", "sm_pmsettings");

    // RegConsoleCmd("sm_repeat", Command_Repeat);
    // PM_AddChatAlias(".repeat", "sm_repeat");

    RegConsoleCmd("sm_stoprepeat", Command_StopRepeat);
    PM_AddChatAlias(".stoprepeat", "sm_stoprepeat");

    // RegConsoleCmd("sm_delay", Command_Delay);
    // PM_AddChatAlias(".delay", "sm_delay");

    RegConsoleCmd("sm_stopall", Command_StopAll);
    PM_AddChatAlias(".stop", "sm_stopall");

    // RegConsoleCmd("sm_roundrepeat", Command_RoundRepeat);
    // PM_AddChatAlias(".roundrepeat", "sm_roundrepeat");
    // PM_AddChatAlias(".rrepeat", "sm_roundrepeat");

    RegConsoleCmd("sm_dryrun", Command_DryRun);
    PM_AddChatAlias(".dry", "sm_dryrun");
    PM_AddChatAlias(".dryrun", "sm_dryrun");

    // RegConsoleCmd("sm_enablesetting", Command_Enable);
    // PM_AddChatAlias(".enable", "sm_enablesetting");

    // RegConsoleCmd("sm_disablesetting", Command_Disable);
    // PM_AddChatAlias(".disable", "sm_disablesetting");

    RegConsoleCmd("sm_god", Command_God);
    PM_AddChatAlias(".god", "sm_god");

    RegConsoleCmd("sm_endround", Command_EndRound);
    PM_AddChatAlias(".endround", "sm_endround");

    RegConsoleCmd("sm_hologram_toggle", Command_HoloNadeToggle);
    PM_AddChatAlias(".holo", "sm_hologram_toggle");
    
    RegConsoleCmd("sm_break", Command_Break);
    PM_AddChatAlias(".break", "sm_break");

    RegConsoleCmd("sm_rr", Command_Restart);
    PM_AddChatAlias(".rr", "sm_rr");
    PM_AddChatAlias(".restart", "sm_rr");
  }
      
  HTM = CreateHudSynchronizer();
  // New Plugin cvars
  g_BotRespawnTimeCvar = CreateConVar("sm_practicemode_bot_respawn_time", "3.0",
                                      "How long it should take bots placed with .bot to respawn");
  g_AutostartCvar = CreateConVar("sm_practicemode_autostart", "1",
                                 "Whether the plugin is automatically started on mapstart");
  g_DryRunFreezeTimeCvar = CreateConVar("sm_practicemode_dry_run_freeze_time", "6",
                                        "Freezetime after running the .dryrun command.");
  g_MaxHistorySizeCvar = CreateConVar(
      "sm_practicemode_max_grenade_history_size", "50",
      "Maximum number of previous grenade throws saved in temporary history per-client. The temporary history is reset every map change. Set to 0 to disable.");
  g_PracModeCanBeStartedCvar =
      CreateConVar("sm_practicemode_can_be_started", "1", "Whether practicemode may be started");
  g_SharedAllNadesCvar = CreateConVar(
      "sm_practicemode_share_all_nades", "0",
      "When set to 1, grenades aren't per-user; they are shared amongst all users that have grenade access. Grenades are not displayed by user, but displayed in 1 grouping. Anyone on the server can edit other users' grenades.");
  g_MaxPlacedBotsCvar =
      CreateConVar("sm_practicemode_max_placed_bots", "10",
                   "Maximum number of static bots a single client may have placed at once.");

  g_FlashEffectiveThresholdCvar =
      CreateConVar("sm_practicemode_flash_effective_threshold", "2.0",
                   "How many seconds a flash must last to be considered effective");
  g_TestFlashTeleportDelayCvar =
      CreateConVar("sm_practicemode_test_flash_delay", "0.3",
                   "Seconds to wait before teleporting a player using .flash");

  g_VersionCvar = CreateConVar("sm_practicemode_version", PLUGIN_VERSION,
                               "Current practicemode version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
  g_VersionCvar.SetString(PLUGIN_VERSION);

  AutoExecConfig(true, "practicemode");

  // New cvars we don't want saved in the autoexec'd file
  g_InfiniteMoneyCvar = CreateConVar("sm_infinite_money", "0",
                                     "Whether clients recieve infinite money", FCVAR_DONTRECORD);
  g_AllowNoclipCvar =
      CreateConVar("sm_allow_noclip", "0",
                   "Whether players may use .noclip in chat to toggle noclip", FCVAR_DONTRECORD);

  g_PatchGrenadeTrajectoryCvar =
      CreateConVar("sm_patch_grenade_trajectory_cvar", "1",
                   "Whether the plugin patches sv_grenade_trajectory with its own grenade trails");
  g_GrenadeTrajectoryClientColorCvar =
      CreateConVar("sm_grenade_trajectory_use_player_color", "0",
                   "Whether to use client colors when drawing grenade trajectories");
  g_RandomGrenadeTrajectoryCvar =
      CreateConVar("sm_grenade_trajectory_random_color", "0",
                   "Whether to randomize all grenade trajectory colors");
  g_GlowPMBotsCvar =
      CreateConVar("sm_glow_pmbots", "0",
                   "Whether to glow all PM Bots");
  g_HoloSpawnsCvar =
      CreateConVar("sm_holo_spawns", "0",
                   "Whether to show spawns holos");
  HookConVarChange(g_GlowPMBotsCvar, GlowPMBotsChanged);
  HookConVarChange(g_HoloSpawnsCvar, HoloSpawnsChanged);

  // Patched builtin cvars
  g_GrenadeTrajectoryCvar = GetCvar("sv_grenade_trajectory");
  g_GrenadeThicknessCvar = GetCvar("sv_grenade_trajectory_thickness");
  g_GrenadeTimeCvar = GetCvar("sv_grenade_trajectory_time");
  g_GrenadeSpecTimeCvar = GetCvar("sv_grenade_trajectory_time_spectator");

  // Set default client cvars
  for (int i = 0; i <= MAXPLAYERS; i++) {
    g_ClientColors[i][0] = 0;
    g_ClientColors[i][1] = 255;
    g_ClientColors[i][2] = 0;
    g_ClientColors[i][3] = 255;
    g_ClientVolume[i] = 1.0;
  }

  g_Spawns = new ArrayList(3);
  g_EnabledHoloNadeAuth = new ArrayList(AUTH_LENGTH);
  g_GrenadeDetonationSaveQueue = new ArrayList();
  g_ManagedGrenadeDetonationsToFix = new StringMap();

  // Create client cookies.
  RegisterUserSetting(UserSetting_ShowAirtime, "practicemode_grenade_airtime", true,
                      "Show grenade airtime");
  RegisterUserSetting(UserSetting_LeaveNadeMenuOpen, "practicemode_leave_menu_open", false,
                      "Leave .nades menu open after selection");
  RegisterUserSetting(UserSetting_NoGrenadeTrajectory, "practicemode_no_traject", false,
                      "Disable grenade trajectories");
  RegisterUserSetting(UserSetting_SwitchToNadeOnSelect, "practicemode_use_ade", true,
                      "Switch to nade on .nades select");
  RegisterUserSetting(UserSetting_StopsRecordingInspectKey, "practicemode_stop_inspect", false,
                      "Stop bot recording on inspect command");

  // Remove cheats so sv_cheats isn't required for this:
  RemoveCvarFlag(g_GrenadeTrajectoryCvar, FCVAR_CHEAT);

  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_hurt", Event_BotDamageDealtEvent, EventHookMode_Pre);
  HookEvent("player_hurt", Event_ReplayBotDamageDealtEvent, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("round_freeze_end", Event_FreezeEnd);
  HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

  g_PugsetupLoaded = LibraryExists("pugsetup");
  g_CSUtilsLoaded = LibraryExists("csutils");

  CreateTimer(1.0, Timer_GivePlayersMoney, _, TIMER_REPEAT);
  CreateTimer(0.1, Timer_RespawnBots, _, TIMER_REPEAT);
  CreateTimer(1.0, Timer_CleanupLivingBots, _, TIMER_REPEAT);
  CreateTimer(1.0, Timer_UpdateClientCvars, _, TIMER_REPEAT);

  HoloNade_PluginStart();
  GrenadeAccuracy_PluginStart();

}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  UpdateHoloNadeEntities();
  UpdateHoloSpawnEntities();
  return Plugin_Continue;
}

public Action FUNCION_PRUEBA(int client, int args) {
  char buffer[256];
  GetCmdArgString(buffer, sizeof(buffer));
  float cacao[3];
  GetClientAbsOrigin(client, cacao);
  PrintToChatAll("%f %f %f", cacao[0], cacao[1], cacao[2]);
  //PM_Message(client, "d");
  return Plugin_Handled;
}

public Action CommandToggleReplayMode(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }
    if (!g_InBotReplayMode) {
        PM_Message(client, "No estas en modo repetición, usa .replays primero.");
        return Plugin_Handled;
    }
    if (IsReplayPlaying()) {
        PM_Message(client, "Termina la repetición actual primero!");
        return Plugin_Handled;
    }
    ServerCommand("botmimicset_replaymode");
    versusMode = !versusMode;
    PM_Message(client, "Se cambio el modo de repetición a: %s", versusMode ? "versus" : "espectador");
    return Plugin_Handled;
}

public Action CommandTogglePauseMode(int client, int args) {
    if (!g_InPracticeMode) {
        return Plugin_Handled;
    }
    if (!g_InBotReplayMode) {
        PM_Message(client, "No estas en modo repetición: usa .replays primero.");
        return Plugin_Handled;
    }
    if (!IsReplayPlaying()) {
        PM_Message(client, "Empieza una repetición primero!");
        return Plugin_Handled;
    }
    if (!versusMode) {
        PM_Message(client, "Cambia el modo de repetición a espectador primero!");
        return Plugin_Handled;
    }
    ServerCommand("botmimictoggle_pausemode");
    pauseMode = !pauseMode;
    PM_Message(client, "Estado de repetición cambiado a: %s", !pauseMode ? "jugando" : "pausado");
    if (pauseMode) {
        GrenadeReplay_PauseGrenades();
    } else {
        GrenadeReplay_ResumeGrenades();
    }
    return Plugin_Handled;
}

public void OnPluginEnd() {
  OnMapEnd();
}

public void OnLibraryAdded(const char[] name) {
  g_PugsetupLoaded = LibraryExists("pugsetup");
  g_CSUtilsLoaded = LibraryExists("csutils");
  g_BotMimicLoaded = LibraryExists("botmimic");
  if (LibraryExists("updater")) {
    Updater_AddPlugin(UPDATE_URL);
  }
}

public void OnLibraryRemoved(const char[] name) {
  g_PugsetupLoaded = LibraryExists("pugsetup");
  g_CSUtilsLoaded = LibraryExists("csutils");
  g_BotMimicLoaded = LibraryExists("botmimic");
}

/**
 * Silences all cvar changes in practice mode.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  if (g_InPracticeMode) {
    event.BroadcastDisabled = true;
  }
  return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  CheckAutoStart();
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client)) {
    if (g_PracticeSetupClient == -2 && IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T) {
      LogMessage("Give Setup to Client %d", client);
      g_PracticeSetupClient = client;
      ServerCommand("mp_restartgame 1");
      CreateTimer(2.0, Timer_FirstPlayerJoin, GetClientSerial(client));
    }
    if (g_SavedRespawnActive[client]) {
      TeleportEntity(client, g_SavedRespawnOrigin[client], g_SavedRespawnAngles[client], NULL_VECTOR);
    }
  }
  if (IsPMBot(client)) {
    GiveBotParams(client);
    if (g_GlowPMBotsCvar.IntValue != 0) {
      RemoveSkin(client);
      CreateGlow(client);
    }
  }

  // TODO: move this elsewhere and save it properly.
  if (g_InBotReplayMode && g_BotMimicLoaded && IsReplayBot(client)) {
    Client_SetArmor(client, 100);
    SetEntData(client, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
  }

  return Plugin_Continue;
}

public Action Timer_FirstPlayerJoin(Handle Timer, int serial) {
  ServerCommand("mp_warmup_end");
  ServerCommand("mp_restartgame 1");
  int client = GetClientFromSerial(serial);
  PracticeSetupMenu(client);
  ShowHelpInfo(client);
  return Plugin_Handled;
}

public void OnClientConnected(int client) {
  SetClientInfo(client, "cl_use_opens_buy_menu", "0");
  g_CurrentSavedGrenadeId[client] = -1;
  g_GrenadeHistoryIndex[client] = -1;
  ClearArray(g_GrenadeHistoryPositions[client]);
  ClearArray(g_GrenadeHistoryAngles[client]);
  ClearArray(g_ClientGrenadeThrowTimes[client]);
  g_TestingFlash[client] = false;
  g_ClientNoFlash[client] = false;
  g_ClientPulledPin[client] = false;
  g_RunningTimeCommand[client] = false;
  g_RunningLiveTimeCommand[client] = false;
  g_SavedRespawnActive[client] = false;
  g_LastGrenadeType[client] = GrenadeType_None;
  g_LastGrenadeEntity[client] = -1;
  g_RunningRepeatedCommand[client] = false;
  g_RunningRoundRepeatedCommandDelay[client].Clear();
  g_RunningRoundRepeatedCommandArg[client].Clear();
  CheckAutoStart();
}

void PrecacheParticle(const char[] sEffectName) {
	static int table = INVALID_STRING_TABLE;
	if (table == INVALID_STRING_TABLE) {
		table = FindStringTable("ParticleEffectNames");
	}

	if (FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX) {
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
	}
}

public void OnMapStart() {
  ReadPracticeSettings();
  // g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
  g_PredictTrail = PrecacheModel("sprites/laserbeam.spr");
  g_BeamSprite = PrecacheModel("materials/sprites/white.vmt");
  PrecacheModel("models/chicken/festive_egg.mdl");
  PrecacheParticle("silvershot_string_lights_02");

  EnforceDirectoryExists("data/practicemode");
  EnforceDirectoryExists("data/practicemode/bots");
  EnforceDirectoryExists("data/practicemode/bots/backups");
  EnforceDirectoryExists("data/practicemode/grenades");
  EnforceDirectoryExists("data/practicemode/grenades/backups");
  EnforceDirectoryExists("data/practicemode/spawns");
  EnforceDirectoryExists("data/practicemode/spawns/backups");
  EnforceDirectoryExists("data/practicemode/replays");
  EnforceDirectoryExists("data/practicemode/replays/backups");

  // This supports backwards compatability for grenades saved in the old location
  // data/practicemode_grenades. The data is transferred to the new
  // location if they are read from the legacy location.
  char legacyDir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, legacyDir, sizeof(legacyDir), "data/practicemode_grenades");

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char legacyFile[PLATFORM_MAX_PATH];
  Format(legacyFile, sizeof(legacyFile), "%s/%s.cfg", legacyDir, map);

  BuildPath(Path_SM, g_GrenadeLocationsFile, sizeof(g_GrenadeLocationsFile),
            "data/practicemode/grenades/%s.cfg", map);

  if (!FileExists(g_GrenadeLocationsFile) && FileExists(legacyFile)) {
    LogMessage("Moving legacy grenade data from %s to %s", legacyFile, g_GrenadeLocationsFile);
    g_GrenadeLocationsKv = new KeyValues("Grenades");
    g_GrenadeLocationsKv.ImportFromFile(legacyFile);
    g_UpdatedGrenadeKv = true;
  } else {
    g_GrenadeLocationsKv = new KeyValues("Grenades");
    g_GrenadeLocationsKv.SetEscapeSequences(true); // Avoid fatals from special chars in user data
    g_GrenadeLocationsKv.ImportFromFile(g_GrenadeLocationsFile);
    g_UpdatedGrenadeKv = false;
  }

  MaybeCorrectGrenadeIds();

  Spawns_MapStart();
  BotReplay_MapStart();
  HoloNade_MapStart();
  GrenadeAccuracy_MapStart();
  // Learn_MapStart();
}

public void OnConfigsExecuted() {
  // Disable legacy plugin if found.
  char legacyPluginFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, legacyPluginFile, sizeof(legacyPluginFile),
            "plugins/pugsetup_practicemode.smx");
  if (FileExists(legacyPluginFile)) {
    char disabledLegacyPluginName[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, disabledLegacyPluginName, sizeof(disabledLegacyPluginName),
              "plugins/disabled/pugsetup_practicemode.smx");
    ServerCommand("sm plugins unload pugsetup_practicemode");
    if (FileExists(disabledLegacyPluginName))
      DeleteFile(disabledLegacyPluginName);
    RenameFile(disabledLegacyPluginName, legacyPluginFile);
    LogMessage("%s was unloaded and moved to %s", legacyPluginFile, disabledLegacyPluginName);
  }

  CheckAutoStart();
}

public void OnGrenadeKvMutate() {
  HoloNade_GrenadeKvMutate();
}

public void CheckAutoStart() {
  // Autostart practicemode if enabled.
  if (g_AutostartCvar.IntValue != 0 && !g_InPracticeMode) {
    bool pugsetup_live = g_PugsetupLoaded && PugSetup_GetGameState() != GameState_None;
    if (!pugsetup_live) {
      LaunchPracticeMode();
    }
  }
}

public void OnClientDisconnect(int client) {
  MaybeWriteNewGrenadeData();
  if (g_IsPMBot[client]) {
    g_IsPMBot[client] = false;
    return;
  }
  if (g_PracticeSetupClient == client) {
    g_PracticeSetupClient = -1;
  }
  if (g_InPracticeMode) {
    KickAllClientBots(client);
  }

  // If the server empties out, exit practice mode.
  int playerCount = 0;
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      if (g_PracticeSetupClient == -1) {
        g_PracticeSetupClient = i;
      }
      playerCount++;
    }
  }
  if (playerCount == 0 && g_InPracticeMode) {
    ExitPracticeMode();
  }

  HoloNade_ClientDisconnect(client);
  // Learn_ClientDisconnect(client);
}

public void OnMapEnd() {
  MaybeWriteNewGrenadeData();

  if (g_InPracticeMode) {
    ExitPracticeMode();
  }

  Spawns_MapEnd();
  BotReplay_MapEnd();
  HoloNade_MapEnd();
  delete g_GrenadeLocationsKv;
}

static void MaybeWriteNewGrenadeData() {
  if (g_UpdatedGrenadeKv) {
    g_GrenadeLocationsKv.Rewind();
    BackupFiles("grenades");
    DeleteFile(g_GrenadeLocationsFile);
    if (!g_GrenadeLocationsKv.ExportToFile(g_GrenadeLocationsFile)) {
      LogError("Failed to write grenade data to %s", g_GrenadeLocationsFile);
    }
    g_UpdatedGrenadeKv = false;
  }
}

public void OnClientSettingsChanged(int client) {
  UpdateClientCvars(client);
}

public void OnClientPutInServer(int client) {
  UpdateClientCvars(client);
  HoloNade_ClientPutInServer(client);
}

static void UpdateClientCvars(int client) {
  if (!g_InPracticeMode) {
    return;
  }

  QueryClientConVar(client, "cl_color", QueryClientColor, client);
  QueryClientConVar(client, "volume", QueryClientVolume, client);
}

public void QueryClientColor(QueryCookie cookie, int client, ConVarQueryResult result,
                      const char[] cvarName, const char[] cvarValue) {
  int color = StringToInt(cvarValue);
  GetColor(view_as<ClientColor>(color), g_ClientColors[client]);
}

public void QueryClientVolume(QueryCookie cookie, int client, ConVarQueryResult result,
                       const char[] cvarName, const char[] cvarValue) {
  g_ClientVolume[client] = StringToFloat(cvarValue);
}

public void GetColor(ClientColor c, int array[4]) {
  int r, g, b;
  switch (c) {
    case ClientColor_Yellow: {
      r = 229;
      g = 224;
      b = 44;
    }
    case ClientColor_Purple: {
      r = 150;
      g = 45;
      b = 225;
    }
    case ClientColor_Green: {
      r = 23;
      g = 255;
      b = 102;
    }
    case ClientColor_Blue: {
      r = 112;
      g = 191;
      b = 255;
    }
    case ClientColor_Orange: {
      r = 227;
      g = 152;
      b = 33;
    }
    default: {
      r = 23;
      g = 255;
      b = 102;
    }
  }
  array[0] = r;
  array[1] = g;
  array[2] = b;
  array[3] = 255;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
                      int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed,
                      int mouse[2]) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  if (IsPMBot(client)) {
    if (g_BotMindControlOwner[client] > 0) {
      int controller = g_BotMindControlOwner[client];
      if (IsPlayer(controller)) {
        if (IsPlayerAlive(controller) && IsPlayerAlive(client)) {
          int playerButtons = GetClientButtons(controller);

          if (playerButtons & IN_FORWARD) vel[0] = 250.0;
          else if (playerButtons & IN_BACK) vel[0] = -250.0;

          if (playerButtons & IN_MOVERIGHT) vel[1] = 250.0;
          else if (playerButtons & IN_MOVELEFT) vel[1] = -250.0;

          if(playerButtons & IN_JUMP){
            buttons &= ~IN_JUMP;
          }
          if ((playerButtons & IN_ATTACK) || (playerButtons & IN_ATTACK2)) {
            g_BotMindControlOwner[client] = -1;
            return Plugin_Changed;
          }

          float botOrigin[3], contAngles[3];
          GetClientEyeAngles(controller, contAngles);
          GetClientAbsOrigin(client, botOrigin);
          g_BotSpawnAngles[client] = contAngles;
          g_BotSpawnOrigin[client] = botOrigin;
          TeleportEntity(client, NULL_VECTOR, contAngles, NULL_VECTOR);

          return Plugin_Changed;
        }
      }
    }

    if (g_BotCrouch[client]) {
      buttons |= IN_DUCK;
    } else {
      buttons &= ~IN_DUCK;
    }

    if (g_BotJump[client]) {
      buttons |= IN_JUMP;
      g_BotJump[client] = false;
    }

    TeleportEntity(client, NULL_VECTOR, g_BotSpawnAngles[client], NULL_VECTOR);

    return Plugin_Continue;
  }

  if (!IsPlayer(client)) {
    return Plugin_Continue;
  }

  bool moving = MovingButtons(buttons);
  TimerType timer_type = g_TimerType[client];
  bool is_movement_timer =
      (timer_type == TimerType_Increasing_Movement || timer_type == TimerType_Countdown_Movement);
  bool is_movement_end_timer = timer_type == TimerType_Increasing_Movement;

  if (g_RunningTimeCommand[client] && is_movement_timer) {
    if (g_RunningLiveTimeCommand[client]) {
      // The movement timer is already running; stop it.
      if (is_movement_end_timer && !moving && GetEntityFlags(client) & FL_ONGROUND) {
        g_RunningTimeCommand[client] = false;
        g_RunningLiveTimeCommand[client] = false;
        StopClientTimer(client);
      }
    } else {
      //  We're pending a movement timer start.
      if (moving) {
        g_RunningLiveTimeCommand[client] = true;
        StartClientTimer(client);
      }
    }
  }
  
  char weaponName[64];
  GetClientWeapon(client, weaponName, sizeof(weaponName));

  if((StrContains(nadelist, weaponName, false) != -1)) {
    if(((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)) && !g_ClientPulledPin[client]) {
        // PrintToChatAll("Grabación empezada.");
        GetClientAbsOrigin(client, g_LastGrenadePinPulledOrigin[client]);
        GetClientEyeAngles(client, g_LastGrenadePinPulledAngles[client]);
        g_ClientPulledPinButtons[client] = 0;
        if (g_PredictMode[client] > GRENADEPREDICT_NONE)
          PrintHintText(client, "Presione [E] Para Desactivar");
        g_ClientPulledPin[client] = true;
    } else if (g_ClientPulledPin[client] && !(buttons & IN_ATTACK) && !(buttons & IN_ATTACK2)) {
        if (buttons & IN_JUMP) g_ClientPulledPinButtons[client] |= IN_JUMP; // jumpthrow: +jump; -attack stops the buttons read
        g_ClientPulledPin[client] = false;
        // PrintToChatAll("Grabación Guardada.");
    } else if (g_ClientPulledPin[client]) {
      if (!(buttons & IN_FORWARD) && !(buttons & IN_BACK) // if player not moving
      && !(buttons & IN_MOVELEFT) && !(buttons & IN_MOVERIGHT)
      && !(buttons & IN_JUMP)) {
        GetClientAbsOrigin(client, g_LastGrenadePinPulledOrigin[client]);
        GetClientEyeAngles(client, g_LastGrenadePinPulledAngles[client]);
        g_ClientPulledPinButtons[client] = 0;
        // PrintToChatAll("Grabacion cancelada.");
        // g_nadeBotRecord[client] = false;
      } else {
        // if (g_nadeBotRecord[client]) {
        //   // PrintToChatAll("Grabación empezada.");
        //   g_nadeBotRecord[client] = true;
        // }
        //PrintToChatAll("...recording...");
        g_ClientPulledPinButtons[client] |= buttons;
      }
    }
  }
  NadePrediction_PlayerRunCmd(client, buttons, weaponName);
  HoloNade_PlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
  //HoloSpawn_PlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
  return Plugin_Continue;
}

static bool MovingButtons(int buttons) {
  return buttons & IN_FORWARD != 0 || buttons & IN_MOVELEFT != 0 || buttons & IN_MOVERIGHT != 0 ||
         buttons & IN_BACK != 0;
}

public Action Command_TeamJoin(int client, const char[] command, int argc) {
  if (!IsValidClient(client) || argc < 1)
    return Plugin_Handled;

  if (g_InPracticeMode) {
    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team = StringToInt(arg);
    SwitchPlayerTeam(client, team);

    // Since we force respawns off during bot replay, make teamswitches respawn players.
    if (g_InBotReplayMode && team != CS_TEAM_SPECTATOR && team != CS_TEAM_NONE) {
      CS_RespawnPlayer(client);
    }

    return Plugin_Handled;
  }

  return Plugin_Continue;
}

public Action Command_Noclip(int client, const char[] command, int argc) {
  PerformNoclipAction(client);
  return Plugin_Handled;
}

public Action Command_SetPos(int client, const char[] command, int argc) {
  SetEntityMoveType(client, MOVETYPE_WALK);
  return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] text) {
  if (g_AllowNoclipCvar.IntValue != 0 && StrEqual(text, ".noclip") && IsPlayer(client)) {
    PerformNoclipAction(client);
  }
  return Plugin_Continue;
}

public void PerformNoclipAction(int client) {
  // The move type is also set on the next frame. This is a dirty trick to deal
  // with clients that have a double-bind of "noclip; say .noclip" to work on both
  // ESEA-practice and local sv_cheats servers. Since this plugin can have both enabled
  // (sv_cheats and allow noclip), this double bind would cause the noclip type to be toggled twice.
  // Therefore the fix is to only perform 1 noclip action per-frame per-client at most, implemented
  // by saving the frame count of each use in g_LastNoclipCommand.
  if (g_LastNoclipCommand[client] == GetGameTickCount() ||
      (g_AllowNoclipCvar.IntValue == 0 && GetCvarIntSafe("sv_cheats") == 0)) {
    return;
  }

  // Stop recording if we are.
  if (g_BotMimicLoaded && g_InBotReplayMode) {
    FinishRecording(client, false);
  }

  g_LastNoclipCommand[client] = GetGameTickCount();
  MoveType t = GetEntityMoveType(client);
  MoveType next = (t == MOVETYPE_WALK) ? MOVETYPE_NOCLIP : MOVETYPE_WALK;
  SetEntityMoveType(client, next);

  if (next == MOVETYPE_WALK) {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
  } else {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 0);
  }
}

public void ReadPracticeSettings() {
  ClearArray(g_BinaryOptionIds);
  ClearArray(g_BinaryOptionNames);
  ClearArray(g_BinaryOptionEnabled);
  ClearArray(g_BinaryOptionChangeable);
  ClearNestedArray(g_BinaryOptionEnabledCvars);
  ClearNestedArray(g_BinaryOptionEnabledValues);
  ClearNestedArray(g_BinaryOptionDisabledCvars);
  ClearNestedArray(g_BinaryOptionDisabledValues);
  ClearArray(g_BinaryOptionCvarRestore);
  ClearArray(g_MapList);

  char filePath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, filePath, sizeof(filePath), "configs/practicemode.cfg");

  KeyValues kv = new KeyValues("practice_settings");
  if (!kv.ImportFromFile(filePath)) {
    LogError("Failed to import keyvalue from practice config file \"%s\"", filePath);
    delete kv;
    return;
  }

  // Read in the binary options
  if (kv.JumpToKey("binary_options")) {
    if (kv.GotoFirstSubKey()) {
      // read each option
      do {
        char id[128];
        kv.GetSectionName(id, sizeof(id));

        char name[OPTION_NAME_LENGTH];
        kv.GetString("name", name, sizeof(name));

        char enabledString[64];
        kv.GetString("default", enabledString, sizeof(enabledString), "enabled");
        bool enabled =
            StrEqual(enabledString, "enabled", false) || StrEqual(enabledString, "enable", false);

        bool changeable = (kv.GetNum("changeable", 1) != 0);

        // read the enabled cvar list
        ArrayList enabledCvars = new ArrayList(CVAR_NAME_LENGTH);
        ArrayList enabledValues = new ArrayList(CVAR_VALUE_LENGTH);
        if (kv.JumpToKey("enabled")) {
          ReadCvarKv(kv, enabledCvars, enabledValues);
          kv.GoBack();
        }

        ArrayList disabledCvars = new ArrayList(CVAR_NAME_LENGTH);
        ArrayList disabledValues = new ArrayList(CVAR_VALUE_LENGTH);
        if (kv.JumpToKey("disabled")) {
          ReadCvarKv(kv, disabledCvars, disabledValues);
          kv.GoBack();
        }

        PM_AddSetting(id, name, enabledCvars, enabledValues, enabled, changeable, disabledCvars,
                      disabledValues);

      } while (kv.GotoNextKey());
    }
  }
  kv.Rewind();

  char map[PLATFORM_MAX_PATH + 1];
  if (kv.JumpToKey("maps")) {
    if (kv.GotoFirstSubKey(false)) {
      do {
        kv.GetSectionName(map, sizeof(map));
        g_MapList.PushString(map);
      } while (kv.GotoNextKey(false));
    }
    kv.GoBack();
  }
  if (g_MapList.Length == 0) {
    g_MapList.PushString("de_cache");
    g_MapList.PushString("de_cbble");
    g_MapList.PushString("de_dust2");
    g_MapList.PushString("de_inferno");
    g_MapList.PushString("de_mirage");
    g_MapList.PushString("de_nuke");
    g_MapList.PushString("de_overpass");
    g_MapList.PushString("de_train");
    g_MapList.PushString("de_vertigo");
  }

  Call_StartForward(g_OnPracticeModeSettingsRead);
  Call_Finish();

  delete kv;
}

public void LaunchPracticeMode() {
  ServerCommand("exec sourcemod/practicemode_start.cfg");

  g_InPracticeMode = true;
  ReadPracticeSettings();
  for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
    ChangeSetting(i, PM_IsSettingEnabled(i), true);
  }

  HoloNade_LaunchPracticeMode();

  // PM_MessageToAll("Modo Práctica esta activado.");
  Call_StartForward(g_OnPracticeModeEnabled);
  Call_Finish();
}

stock bool ChangeSetting(int index, bool enabled, bool force_setting = false) {
  bool previousSetting = g_BinaryOptionEnabled.Get(index);
  if (enabled == previousSetting && !force_setting) {
    return false;
  }

  g_BinaryOptionEnabled.Set(index, enabled);

  if (enabled) {
    ArrayList cvars = g_BinaryOptionEnabledCvars.Get(index);
    ArrayList values = g_BinaryOptionEnabledValues.Get(index);
    g_BinaryOptionCvarRestore.Set(index, SaveCvars(cvars));
    ExecuteCvarLists(cvars, values);
  } else {
    ArrayList cvars = g_BinaryOptionDisabledCvars.Get(index);
    ArrayList values = g_BinaryOptionDisabledValues.Get(index);

    if (cvars != null && cvars.Length > 0 && values != null && values.Length == cvars.Length) {
      // If there are are disabled cvars explicity set.
      ExecuteCvarLists(cvars, values);
    } else {
      // If there are no "disabled" cvars explicity set, we'll just restore to the cvar
      // values before the option was enabled.
      Handle cvarRestore = g_BinaryOptionCvarRestore.Get(index);
      if (cvarRestore != INVALID_HANDLE) {
        RestoreCvars(cvarRestore, true);
        g_BinaryOptionCvarRestore.Set(index, INVALID_HANDLE);
      }
    }
  }

  char id[OPTION_NAME_LENGTH];
  char name[OPTION_NAME_LENGTH];
  g_BinaryOptionIds.GetString(index, id, sizeof(id));
  g_BinaryOptionNames.GetString(index, name, sizeof(name));

  Call_StartForward(g_OnPracticeModeSettingChanged);
  Call_PushCell(index);
  Call_PushString(id);
  Call_PushString(name);
  Call_PushCell(enabled);
  Call_Finish();

  return true;
}

public void ExitPracticeMode() {
  if (!g_InPracticeMode) {
    return;
  }

  Call_StartForward(g_OnPracticeModeDisabled);
  Call_Finish();

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && IsFakeClient(i) && g_IsPMBot[i]) {
      KickClient(i);
      g_IsPMBot[i] = false;
    }
  }

  for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
    ChangeSetting(i, false);

    // Restore the cvar values if they haven't already been.
    Handle cvarRestore = g_BinaryOptionCvarRestore.Get(i);
    if (cvarRestore != INVALID_HANDLE) {
      RestoreCvars(cvarRestore, true);
      g_BinaryOptionCvarRestore.Set(i, INVALID_HANDLE);
    }
  }

  g_InPracticeMode = false;
  g_PracticeSetupClient = -2;

  // force turn noclip off for everyone
  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = false;
    if (IsValidClient(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  HoloNade_ExitPracticeMode();
  Spawns_ExitPracticeMode();
  
  SetConVarString(FindConVar("sv_password"), "");
  ServerCommand("exec sourcemod/practicemode_end.cfg");
  // PM_MessageToAll("Modo Práctica esta desactivado.");
}

public Action Timer_GivePlayersMoney(Handle timer) {
  int maxMoney = GetCvarIntSafe("mp_maxmoney", 16000);
  if (g_InfiniteMoneyCvar.IntValue != 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        SetEntProp(i, Prop_Send, "m_iAccount", maxMoney);
      }
    }
  }

  return Plugin_Continue;
}

public Action Timer_UpdateClientCvars(Handle timer) {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      UpdateClientCvars(i);
    }
  }
  return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] className) {
  if (!IsValidEntity(entity)) {
    return;
  }

  SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

// We artifically delay the work here in OnEntitySpawned because the csutils
// plugin will spawn grenades and set the owner on spawn, and we want to be sure
// the owner is set by the time practicemode gets to the grenade.
public void OnEntitySpawned(int entity) {
  RequestFrame(DelayedOnEntitySpawned, entity);
}

public void DelayedOnEntitySpawned(int entity) {
  if (!IsValidEdict(entity)) {
    return;
  }

  char className[CLASS_LENGTH];
  GetEdictClassname(entity, className, sizeof(className));

  if (IsGrenadeProjectile(className)) {
    // Get the cl_color value for the client that threw this grenade.
    int client = Entity_GetOwner(entity);
    if (IsPlayer(client) && g_InPracticeMode &&
    GrenadeFromProjectileName(className) == GrenadeType_Smoke) {
      int index = g_ClientGrenadeThrowTimes[client].Push(EntIndexToEntRef(entity));
      g_ClientGrenadeThrowTimes[client].Set(index, view_as<int>(GetEngineTime()), 1);
    }
    if (IsReplayBot(client) && g_InPracticeMode &&
    (GrenadeFromProjectileName(className) != GrenadeType_None || GrenadeFromProjectileName(className) != GrenadeType_Smoke)) {
      g_currentReplayGrenade++;
      SetEntProp(entity, Prop_Data, "m_iTeamNum", g_currentReplayGrenade);
      g_ClientReplayGrenadeThrowTime[g_currentReplayGrenade] = GetEngineTime();
    }

    if (IsValidEntity(entity)) {
      if (g_GrenadeTrajectoryCvar.IntValue != 0 && g_PatchGrenadeTrajectoryCvar.IntValue != 0) {
        // Send a temp ent beam that follows the grenade entity to all other clients.
        for (int i = 1; i <= MaxClients; i++) {
          if (!IsClientConnected(i) || !IsClientInGame(i)) {
            continue;
          }

          if (GetSetting(client, UserSetting_NoGrenadeTrajectory)) {
            continue;
          }

          // Note: the technique using temporary entities is taken from InternetBully's NadeTails
          // plugin which you can find at https://forums.alliedmods.net/showthread.php?t=240668
          float time = (GetClientTeam(i) == CS_TEAM_SPECTATOR) ? g_GrenadeSpecTimeCvar.FloatValue
                                                               : g_GrenadeTimeCvar.FloatValue;

          int colors[4];
          if (g_RandomGrenadeTrajectoryCvar.IntValue > 0) {
            colors[0] = GetRandomInt(0, 255);
            colors[1] = GetRandomInt(0, 255);
            colors[2] = GetRandomInt(0, 255);
            colors[3] = 255;
          } else if (g_GrenadeTrajectoryClientColorCvar.IntValue > 0 && IsPlayer(client)) {
            colors = g_ClientColors[client];
          } else {
            colors = g_ClientColors[0];
          }

          TE_SetupBeamFollow(entity, g_BeamSprite, 0, time, g_GrenadeThicknessCvar.FloatValue * 5,
                             g_GrenadeThicknessCvar.FloatValue * 5, 1, colors);
          TE_SendToClient(i);
        }
      }

      // If the user recently indicated they are testing a flash (.flash),
      // teleport to that spot.
      if (GrenadeFromProjectileName(className) == GrenadeType_Flash && g_TestingFlash[client]) {
        float delay = g_TestFlashTeleportDelayCvar.FloatValue;
        if (delay <= 0.0) {
          delay = 0.1;
        }
        CreateTimer(delay, Timer_TeleportClient, GetClientSerial(client));
      }
    }
  }
}

public void OnEntityDestroyed(int entity) {
  HoloNade_EntityDestroyed(entity);
}

public Action Timer_TeleportClient(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (g_InPracticeMode && IsPlayer(client) && g_TestingFlash[client]) {
    float velocity[3];
    TeleportEntity(client, g_TestingFlashOrigins[client], g_TestingFlashAngles[client], velocity);
    SetEntityMoveType(client, MOVETYPE_NONE);
  }
  return Plugin_Handled;
}

public Action Event_WeaponFired(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  char weapon[CLASS_LENGTH];
  event.GetString("weapon", weapon, sizeof(weapon));

  if (IsGrenadeWeapon(weapon) && IsPlayer(client)) {
    AddGrenadeToHistory(client);
  }
  return Plugin_Continue;
}

public Action Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }
  GrenadeDetonateTimerHelper(event, "smoke grenade");
  return Plugin_Continue;
}

public Action Event_PlayerBlind(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  // Did anyone throw a flash recently? If so, they probably care about this bot being blinded.
  float now = GetGameTime();
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && FloatAbs(now - g_LastFlashDetonateTime[i]) < 0.001) {
      char T_CB[16];
      if(GetFlashDuration(victim)>=g_FlashEffectiveThresholdCvar.FloatValue) T_CB="{GREEN}";
      else T_CB="{DARK_RED}";
      PM_Message(i, "{PURPLE}------------");
      PM_Message(i, "{ORANGE}Flash a : %N", victim);
      float accuracy = GetFlashDuration(victim)/5.21*100;
      accuracy > 100.0 ? (accuracy=100.0) : accuracy;
      PM_Message(i, "Precisión de Flash: %s%.1f%%", T_CB, accuracy);
      PM_Message(i, "Duración de Flash: %s%.1f{NORMAL}s", T_CB, GetFlashDuration(victim));
      PM_Message(i, "{PURPLE}------------");
      break;
    }
  }

  // TODO: move this into another place (has nothing to do with bots!)
  if (g_ClientNoFlash[victim]) {
    RequestFrame(KillFlashEffect, GetClientSerial(victim));
  }
  return Plugin_Handled;
}

public void KillFlashEffect(int serial) {
  int client = GetClientFromSerial(serial);
  // Idea used from SAMURAI16 @ https://forums.alliedmods.net/showthread.php?p=685111
  SetEntDataFloat(client, FindSendPropInfo("CCSPlayer", "m_flFlashMaxAlpha"), 0.5);
}

public void GrenadeDetonateTimerHelper(Event event, const char[] grenadeName) {
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  int entity = event.GetInt("entityid");

  if (IsPlayer(client)) {
    for (int i = 0; i < g_ClientGrenadeThrowTimes[client].Length; i++) {
      int ref = g_ClientGrenadeThrowTimes[client].Get(i, 0);
      if (EntRefToEntIndex(ref) == entity) {
        float dt = GetEngineTime() - view_as<float>(g_ClientGrenadeThrowTimes[client].Get(i, 1));
        g_ClientGrenadeThrowTimes[client].Erase(i);
        if (GetSetting(client, UserSetting_ShowAirtime)) {
          PM_Message(client, "Tiempo en aire de %s: %.1f segundos", grenadeName, dt);
        }
        ForceGlow(entity);
        break;
      }
    }
  }
}

stock void ForceGlow(int entity) {
  int glowEnt = CreateEntityByName("prop_dynamic_override");
  if (glowEnt != -1) {
    char entModel[512];
    float origin[3], angles[3];
    Entity_GetModel(entity, entModel, sizeof(entModel));
    Entity_GetAbsOrigin(entity, origin);
    Entity_GetAbsAngles(entity, angles);
    DispatchKeyValue(glowEnt, "classname", "prop_dynamic_override");
    DispatchKeyValue(glowEnt, "spawnflags", "1");
    DispatchKeyValue(glowEnt, "renderamt", "255");
    DispatchKeyValue(glowEnt, "rendermode", "1");
    DispatchKeyValue(glowEnt, "model", entModel);
    if (!DispatchSpawn(glowEnt)) {
      return;
    }
    TeleportEntity(glowEnt, origin, angles, NULL_VECTOR);
    SetEntProp(glowEnt, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(glowEnt, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(glowEnt, Prop_Send, "m_flGlowMaxDist", 10000.0);
    SetVariantString("!activator");
    AcceptEntityInput(glowEnt, "SetParent", entity);
  }
}

public Action Event_FlashDetonate(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  if (IsPlayer(client) && g_TestingFlash[client]) {
    // Get the impact of the flash next frame, since doing it in
    // this frame doesn't work.
    //RequestFrame(GetTestingFlashInfo, GetClientSerial(client));
    CreateTimer(1.5, Timer_FakeGrenadeBack, GetClientSerial(client));
  }
  g_LastFlashDetonateTime[client] = GetGameTime();
  return Plugin_Continue;
}

// public void GetTestingFlashInfo(int serial) {
//   int client = GetClientFromSerial(serial);
//   if (IsPlayer(client) && g_TestingFlash[client]) {
//     float flashDuration = GetFlashDuration(client);

//     if (flashDuration < g_FlashEffectiveThresholdCvar.FloatValue) {
//       CreateTimer(1.0, Timer_FakeGrenadeBack, GetClientSerial(client));
//     } else {
//       float delay = flashDuration - 1.0;
//       if (delay <= 0.0)
//         delay = 0.1;
//       CreateTimer(delay, Timer_FakeGrenadeBack, GetClientSerial(client));
//     }
//   }
// }

public Action Timer_FakeGrenadeBack(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (g_InPracticeMode && IsPlayer(client)) {
    FakeClientCommand(client, "sm_lastgrenade");
  }
  return Plugin_Handled;
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  for (int i = 1; i <= MaxClients; i++) {
    if (!IsPlayer(i)) {
      continue;
    }

    if (g_ClientNoFlash[i]) {
      g_ClientNoFlash[i] = false;
      PM_Message(i, "Noflash desactivado al inicio de la ronda.");
    }

    if (GetEntityMoveType(i) == MOVETYPE_NOCLIP) {
      SetEntityMoveType(i, MOVETYPE_WALK);
      PM_Message(i, "Noclip desactivado al inicio de la ronda.");
    }

    FreezeEnd_RoundRepeat(i);
  }

  return Plugin_Handled;
}

public void HoloSpawnsChanged(Handle convar, const char[] oldValue, const char[] newValue) {
  if (StringToInt(newValue) == 1) {
    UpdateHoloSpawnEntities();
  } else if (StringToInt(newValue) == 0) {
    RemoveHoloSpawnEntities();
  }
}

public void GlowPMBotsChanged(Handle convar, const char[] oldValue, const char[] newValue) {
  if (StringToInt(newValue) == 1) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPMBot(i)) {
        RemoveSkin(i);
        CreateGlow(i);
      }
    }
  } else if (StringToInt(newValue) == 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPMBot(i)) {
        RemoveSkin(i);
      }
    }
  }
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand,
                           const char[] chatArgs, int client) {
  if (StrEqual(chatCommand, alias, false)) {
    // Get the original cmd reply source so it can be restored after the fake client command.
    // This means and ReplyToCommand will go into the chat area, rather than console, since
    // *chat* aliases are for *chat* commands.
    ReplySource replySource = GetCmdReplySource();
    SetCmdReplySource(SM_REPLY_TO_CHAT);
    char fakeCommand[256];
    Format(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
    FakeClientCommand(client, fakeCommand);
    SetCmdReplySource(replySource);
    return true;
  }
  return false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (!IsPlayer(client))
    return;

  // splits to find the first word to do a chat alias command check
  char chatCommand[COMMAND_LENGTH];
  char chatArgs[255];
  int index = SplitString(sArgs, " ", chatCommand, sizeof(chatCommand));

  if (index == -1) {
    strcopy(chatCommand, sizeof(chatCommand), sArgs);
  } else if (index < strlen(sArgs)) {
    strcopy(chatArgs, sizeof(chatArgs), sArgs[index]);
  }

  if (chatCommand[0]) {
    char alias[ALIAS_LENGTH];
    char cmd[COMMAND_LENGTH];
    for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
      g_ChatAliases.GetString(i, alias, sizeof(alias));
      g_ChatAliasesCommands.GetString(i, cmd, sizeof(cmd));

      if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client)) {
        break;
      }
    }
  }

  if (!g_PugsetupLoaded) {
    if (StrEqual(chatCommand, ".menu")) {
      GivePracticeMenu(client);
    }
  }
}

public Action Command_GivePracticeSetupMenu(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (!IsPracticeSetupClient(client)) {
    return Plugin_Handled;
  }
  PracticeSetupMenu(client);
  return Plugin_Handled;
}

public void PracticeSetupMenu(int client) {
  Menu menu = new Menu(PracticeSetupMenuHandler);
  menu.SetTitle("Configuración del Servidor");

  char buffer[128];
  GetConVarString(FindConVar("sv_password"), buffer, sizeof(buffer));
  if (!StrEqual(buffer, "")) {
    Format(buffer, sizeof(buffer), "%s %s", "Acceso al servidor:", "Con Contraseña");
    menu.AddItem("password", buffer);
    menu.AddItem("changepassword", "Cambiar contraseña\n ");
  } else {
    Format(buffer, sizeof(buffer), "%s %s", "Acceso al servidor:", "Sin Contraseña");
    menu.AddItem("password", buffer);
    menu.AddItem("changepassword", "Cambiar contraseña\n ", ITEMDRAW_DISABLED);
  }

  char enabled[32];
  GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(8), client);
  Format(buffer, sizeof(buffer), "%s: %s", "Mostrar impactos de bala: ", enabled);
  menu.AddItem("8", buffer);

  GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(3), client);
  Format(buffer, sizeof(buffer), "%s: %s", "Munición Infinita: ", enabled);
  menu.AddItem("3", buffer);

  GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(11), client);
  Format(buffer, sizeof(buffer), "%s: %s", "Bots Wallhack: ", enabled);
  menu.AddItem("11", buffer);

  GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(5), client);
  Format(buffer, sizeof(buffer), "%s: %s", "Trayectoria de Granada: ", enabled);
  menu.AddItem("5", buffer);

  GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(12), client);
  Format(buffer, sizeof(buffer), "%s: %s\n ", "Mostrar Spawns: ", enabled);
  menu.AddItem("12", buffer);

  menu.AddItem("changemap", "Cambiar mapa");

  menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public int PracticeSetupMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "password")) {
      char SvPassword[MAX_PASSWORD_LENGTH];
      GetConVarString(FindConVar("sv_password"), SvPassword, sizeof(SvPassword));
      if (!StrEqual(SvPassword, "")) {
        SetConVarString(FindConVar("sv_password"), "");
      } else {
        PM_Message(client, "{ORANGE}Escriba la nueva contraseña. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
        g_WaitForServerPassword = true;
      }
    } else if (StrEqual(buffer, "changepassword")) {
        PM_Message(client, "{ORANGE}Escriba la nueva contraseña. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
        g_WaitForServerPassword = true;
    } else if (StrEqual(buffer, "8")) {
      ChangeSetting(8, !PM_IsSettingEnabled(8), true);
    } else if (StrEqual(buffer, "3")) {
      ChangeSetting(3, !PM_IsSettingEnabled(3), true);
    } else if (StrEqual(buffer, "11")) {
      ChangeSetting(11, !PM_IsSettingEnabled(11), true);
    } else if (StrEqual(buffer, "5")) {
      ChangeSetting(5, !PM_IsSettingEnabled(5), true);
    } else if (StrEqual(buffer, "12")) {
      ChangeSetting(12, !PM_IsSettingEnabled(12), true);
    } else if (StrEqual(buffer, "changemap")) {
      Command_Map(client, 0);
    }
    PracticeSetupMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void GivePracticeMenu(int client, int style = ITEMDRAW_DEFAULT) {
  Menu menu = new Menu(PracticeMenuHandler);
  menu.SetTitle("Menu de Práctica");
  menu.AddItem("bots_menu", "Menu de Bots");
  menu.AddItem("nades_menu", "Menu de Granadas\n ");
  
  menu.AddItem("help", "Ayuda");

  menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public Action ChatListener(int client, const char[] command, int args) {
  if (IsPlayer(client) && !IsChatTrigger()) {
    if (g_WaitForSaveNade[client]) {
      g_WaitForSaveNade[client] = false;
      char name[GRENADE_NAME_LENGTH]; GetCmdArgString(name, sizeof(name)); CleanMsgString(name, sizeof(name));
      SaveClientNade(client, name);
    } else if (g_WaitForServerPassword && client == g_PracticeSetupClient) {
      char msg[MAX_PASSWORD_LENGTH]; GetCmdArgString(msg, sizeof(msg)); CleanMsgString(msg, sizeof(msg));
      g_WaitForServerPassword = false;
      if (StrEqual(msg, "!no")) {
        PM_Message(client, "Cancelado.");
      } else {
        SetConVarString(FindConVar("sv_password"), msg);
        PM_Message(client, "Contraseña Cambiada a \"{ORANGE}%s{NORMAL}\".", msg);
      }
      PracticeSetupMenu(client);
      return Plugin_Handled;
    }
  }
  return Plugin_Continue;
}

stock void CleanMsgString(char[] msg, int size) {
  ReplaceString(msg, size, "%", "％");
  while (StrContains(msg, "  ") > -1) {
    ReplaceString(msg, size, "  ", " ");
  }
  StripQuotes(msg);
}

public int PracticeMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    
    if (StrEqual(buffer, "bots_menu")) {
      Command_BotsMenu(client, 0);
    } else if (StrEqual(buffer, "nades_menu")) {
      GiveNadesMenu(client);
    } else {
      if (StrEqual(buffer, "help")) {
        ShowHelpInfo(client);
      }
      GivePracticeMenu(client);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action Command_GiveHelpInfo(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  int page;
  page = GetCmdArgInt(args);
  if (page <= 1) {
    ShowHelpInfo(client, 1);
  } else if (page == 2) {
    ShowHelpInfo(client, 2);
  }
  return Plugin_Handled;
}

stock void ShowHelpInfo(int client, int page = 1) {
  if (page == 1) {
    PM_Message(client, "{GREEN}.setup: {PURPLE}Menu Principal de Administrador del Servidor");
    PM_Message(client, "{GREEN}.menu: {PURPLE}Menu Para todos los Usuarios");
    PM_Message(client, "{GREEN}.save <nombre>: {PURPLE}Guarda tu última granada");
    PM_Message(client, "{GREEN}.copy: {PURPLE}Copia el último lineup de un jugador");
    PM_Message(client, "{GREEN}.throw: {PURPLE}Tira tu última granada <O el nombre de una guardada>");
    PM_Message(client, "{GREEN}.flash: {PURPLE}Guarda tu posicion para probar una flash");
    PM_Message(client, "{GREEN}.last: {PURPLE}Ve a tu último lineup");
    PM_Message(client, "{GREEN}.clear: {PURPLE}Limpia instantáneamente los humos y molos");
    PM_Message(client, "{GREEN}.map: {PURPLE}Menú de cambio de mapa");
    PM_Message(client, "{GREEN}.bots: {PURPLE}Muestra el menu de los bots");
    PM_Message(client, "{ORANGE}Con una Granada Equipada:");
    PM_Message(client, "{GREEN}Presione {PURPLE}[E] {GREEN}Para cambiar el tipo de trayectoria de la granada.");
    PM_Message(client, "{GREEN}Mantenga {PURPLE}[R] {GREEN}para hacer ver donde caerá la granada");
    PM_Message(client, "{GREEN}.help <pagina>: {PURPLE}Lista de Comandos [1/2]");
  } else if (page == 2) {
    PM_Message(client, "{GREEN}.back: {PURPLE}Regresa 1 en tu historial de lineups");
    PM_Message(client, "{GREEN}.forward: {PURPLE}Avanza 1 en tu historial de lineups");
    PM_Message(client, "{GREEN}.noflash: {PURPLE}Activa/Desactiva Antiflash");
    PM_Message(client, "{GREEN}.timer .timer2: {PURPLE}Temporizadores");
    PM_Message(client, "{GREEN}.god");
    PM_Message(client, "{GREEN}.rr <segundos>: {PURPLE}Reinicia la ronda con delay de <segundos> para compra");
  }
}

bool CanStartPracticeMode(int client) {
  if (g_PracModeCanBeStartedCvar.IntValue == 0) {
    return false;
  }
  return CheckCommandAccess(client, "sm_prac", ADMFLAG_CHANGEMAP);
}

public void CSU_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3],
                        const float velocity[3]) {
  g_LastGrenadeType[client] = grenadeType;
  g_LastGrenadeOrigin[client] = origin;
  g_LastGrenadeVelocity[client] = velocity;
  g_LastGrenadeDetonationOrigin[client] = view_as<float>({0.0, 0.0, 0.0});
  g_LastGrenadeEntity[client] = entity;
  Replays_OnThrowGrenade(client, entity, grenadeType, origin, velocity);
  GrenadeAccuracy_OnThrowGrenade(client, entity);
}

public void CSU_OnGrenadeExplode(
  int client,
  int currentEntity, 
  GrenadeType grenade,
  const float grenadeDetonationOrigin[3]
) {
  if (client == -1) {
    // I guess this is possible in some race conditions involving map change or disconnect.
    return;
  }
  if (currentEntity == g_LastGrenadeEntity[client]) {
    g_LastGrenadeDetonationOrigin[client] = grenadeDetonationOrigin;
  }
  if (g_GrenadeDetonationSaveQueue.Length > 0) {
    // Process the async save queue to add detonation data.
    for (int i = g_GrenadeDetonationSaveQueue.Length - 1; i >= 0; i--) {
    // for (int i = 0; i < g_GrenadeDetonationSaveQueue.Length; i++) {
      StringMap item = g_GrenadeDetonationSaveQueue.Get(i);

      int grenadeEntity;
      if (!item.GetValue(GRENADE_DETONATION_KEY_ENTITY, grenadeEntity)) {
        LogError("Tried to access a prop " ... GRENADE_DETONATION_KEY_ENTITY ... " that didn't exist in OnGrenadeExplode");
      }

      if (grenadeEntity == currentEntity) {
        char auth[AUTH_LENGTH];
        if (!item.GetString(GRENADE_DETONATION_KEY_AUTH, auth, sizeof(auth))) {
          LogError("Tried to access a prop "  ... GRENADE_DETONATION_KEY_AUTH ... " that didn't exist in OnGrenadeExplode");
        }
        char grenadeID[GRENADE_ID_LENGTH];
        if (!item.GetString(GRENADE_DETONATION_KEY_ID, grenadeID, sizeof(grenadeID))) {
          LogError("Tried to access a prop "  ... GRENADE_DETONATION_KEY_ID ... " that didn't exist in OnGrenadeExplode");
        }
        SetGrenadeVector(auth, grenadeID, "grenadeDetonationOrigin", grenadeDetonationOrigin);
      }
    }
    // All grenades processed.
    g_GrenadeDetonationSaveQueue.Clear();
  }
  GrenadeAccuracy_OnGrenadeExplode(client, currentEntity, grenade, grenadeDetonationOrigin);
  // Learn_OnGrenadeExplode(client, currentEntity, grenade, grenadeDetonationOrigin);
}

public void CSU_OnManagedGrenadeExplode(
  int client,
  int currentEntity, 
  GrenadeType grenade,
  const float grenadeDetonationOrigin[3]
) {
  if (g_ManagedGrenadeDetonationsToFix.Size == 0) {
    return;
  }

  char key[128];
  IntToString(currentEntity, key, sizeof(key));

  Handle p;
  if (g_ManagedGrenadeDetonationsToFix.GetValue(key, p)) {
    char auth[AUTH_LENGTH];
    ReadPackString(p, auth, sizeof(auth));

    char grenadeID[GRENADE_ID_LENGTH];
    ReadPackString(p, grenadeID, sizeof(grenadeID));
    
    SetGrenadeVector(auth, grenadeID, "grenadeDetonationOrigin", grenadeDetonationOrigin);
    
    CloseHandle(p);
    g_ManagedGrenadeDetonationsToFix.Remove(key);
    PM_Message(
      client, 
      "Detonación arreglada para la granada %s. Granadas faltando para esta fase: %i.", 
      grenadeID, 
      g_ManagedGrenadeDetonationsToFix.Size
    );
  }

  // Did we finish the queue?
  if (g_ManagedGrenadeDetonationsToFix.Size == 0) {
    int nextPhase = CorrectGrenadeDetonationsAdvanceToNextPhase(client);
    if (nextPhase == GRENADE_DETONATION_FIX_PHASE_DONE) {
      PM_Message(client, "Terminando de arreglar detonaciones.");
    } else {
      PM_Message(client, "Fases restantes: %i.", nextPhase);
    }
  }
}