#define UPDATE_URL "https://dl.whiffcity.com/plugins/practicemode/practicemode.txt"
#define PLUGIN_VERSION "2.0.1-dev"

#include <clientprefs>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>
#include <vector>

#undef REQUIRE_PLUGIN
#include "botmimic.inc"
#include "csutils.inc"

#include "practicemode.inc"
#include "practicemode/util.sp"

#pragma semicolon 1
#pragma newdecls required

#define MAX_PASSWORD_LENGTH 32

bool g_InPracticeMode = false;
bool g_InDryMode = false;
bool g_InRetakeMode = false;
bool g_InCrossfireMode = false;
bool g_CSUtilsLoaded = false;
bool g_BotMimicLoaded = false;

/** Chat aliases loaded **/
#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

Handle HudSync;

// Plugin cvars
ConVar g_AutostartCvar;
ConVar g_BotRespawnTimeCvar;
ConVar g_DryRunFreezeTimeCvar;
ConVar g_MaxHistorySizeCvar;
ConVar g_MaxPlacedBotsCvar;

// Infinite money data
ConVar g_InfiniteMoneyCvar;

int g_PredictTrail = -1;

int g_BeamSprite = -1;
ConVar g_PatchGrenadeTrajectoryCvar;

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
#define GRENADE_EXECUTION_LENGTH 128
// #define GRENADE_DESCRIPTION_LENGTH 256
#define GRENADE_NAME_LENGTH 64
#define GRENADE_ID_LENGTH 16
#define AUTH_LENGTH 64
#define GRENADE_CODE_LENGTH 256

bool g_WaitForServerPassword = false;
bool g_WaitForDemoSave[MAXPLAYERS + 1] = {false, ...};
bool g_WaitForSingleDemoRoleName[MAXPLAYERS + 1] = {false, ...};
bool g_WaitForSingleDemoName[MAXPLAYERS + 1] = {false, ...};
bool g_WaitForSaveNade[MAXPLAYERS + 1] = {false, ...};

int g_recordingNadeDemoStatus[MAXPLAYERS + 1] = {0, ...};// 0 = not recording/canceled, 1 = recording, 2 = not recording/saved
bool g_savedNewNadeDemo[MAXPLAYERS + 1] = {false, ...};
char g_GrenadeLocationsFile[PLATFORM_MAX_PATH];

Database g_db = null;
char g_dbMap[PLATFORM_MAX_PATH];

// // KeyValues g_GrenadeLocationsKv;  // Inside any global function, we expect this to be at the root level.
int g_CurrentSavedGrenadeId[MAXPLAYERS + 1];
bool g_UpdatedGrenadeKv = false;  // whether there has been any changed the kv structure this map
int g_NextID = 0;
// int g_currentReplayGrenade = -1;
int g_currentDemoGrenade = -1;

// Grenade Holograms
ArrayList g_EnabledHoloNadeAuth = null;
bool g_HoloNadeLoadDefault = false;

// Grenade history data
int g_GrenadeHistoryIndex[MAXPLAYERS + 1];

ArrayList g_GrenadeHistoryPositions[MAXPLAYERS + 1];
ArrayList g_GrenadeHistoryAngles[MAXPLAYERS + 1];

ArrayList g_ClientGrenadeThrowTimes[MAXPLAYERS + 1];  // ArrayList of <int entity, float throw time, int bounces>
                                                      // pairs of live grenades
bool g_TestingFlash[MAXPLAYERS + 1];
float g_TestingFlashOrigins[MAXPLAYERS + 1][3];
float g_TestingFlashAngles[MAXPLAYERS + 1][3];

bool g_ClientNoFlash[MAXPLAYERS + 1];
float g_LastFlashDetonateTime[MAXPLAYERS + 1];

#define MAX_SIM_REPLAY_NADES 40

GrenadeType g_LastGrenadeType[MAXPLAYERS + 1];
int g_ClientPulledPinButtons[MAXPLAYERS + 1];
bool g_ClientPulledPin[MAXPLAYERS + 1] = {false, ...};
float g_LastGrenadePinPulledOrigin[MAXPLAYERS + 1][3];
float g_LastGrenadePinPulledAngles[MAXPLAYERS + 1][3];
float g_LastGrenadeOrigin[MAXPLAYERS + 1][3];
float g_LastGrenadeVelocity[MAXPLAYERS + 1][3];
float g_LastGrenadeDetonationOrigin[MAXPLAYERS + 1][3];
float g_ClientDemoGrenadeThrowTime[MAX_SIM_REPLAY_NADES];
// #define GRENADE_DETONATE_FLASH_TIME 1.658
// #define GRENADE_DETONATE_MOLOTOV_TIME 1.96
// float g_ClientReplayGrenadeThrowTime[MAX_SIM_REPLAY_NADES];
// float g_TiempoRecorrido[MAX_SIM_REPLAY_NADES] = {0.0, ...};
// Handle ExplodeNadeTimer[MAX_SIM_REPLAY_NADES] = {INVALID_HANDLE, ...};
// float g_ReplayGrenadeLastPausedTime = -1.0;
// float g_ReplayGrenadeLastResumedTime[MAX_SIM_REPLAY_NADES] = {-1.0, ...};
// float g_ReplayGrenadeLastLastResumedTime[MAX_SIM_REPLAY_NADES] ={ -1.0, ...};
int g_LastGrenadeEntity[MAXPLAYERS + 1];

char nadelist[128] = "weapon_hegrenade weapon_smokegrenade weapon_flashbang weapon_incgrenade weapon_tagrenade weapon_molotov weapon_decoy";

int g_ClientSpecBot[MAXPLAYERS + 1] = {-1, ...};
float g_LastSpecPlayerPos[MAXPLAYERS + 1][3];
float g_LastSpecPlayerAng[MAXPLAYERS + 1][3];
int g_LastSpecPlayerTeam[MAXPLAYERS + 1];

char g_BotOriginalName[MAXPLAYERS + 1][MAX_NAME_LENGTH]; // Used for kicking them, otherwise they rejoin
bool g_IsPMBot[MAXPLAYERS + 1];
int g_IsDemoBot[MAXPLAYERS + 1] = {0, ...}; //0 = not a demo bot, else role number
bool g_IsRetakeBot[MAXPLAYERS + 1];
bool g_IsCrossfireBot[MAXPLAYERS + 1];
bool g_IsNadeDemoBot[MAXPLAYERS + 1];
float g_BotSpawnOrigin[MAXPLAYERS + 1][3];
float g_BotSpawnAngles[MAXPLAYERS + 1][3];
char g_BotSpawnWeapon[MAXPLAYERS + 1][64];
bool g_BotCrouch[MAXPLAYERS + 1];
bool g_BotJump[MAXPLAYERS + 1];
int g_BotMindControlOwner[MAXPLAYERS + 1] = {-1, ...};
int g_BotNameNumber[MAXPLAYERS + 1];

bool g_InBotDemoMode = false;
KeyValues g_DemosKv;

#define PLAYER_HEIGHT 72.0
#define CLASS_LENGTH 64

const int kMaxBackupsPerMap = 50;


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

// Data storing spawn priorities.
ArrayList g_Spawns = null;

// Forwards
Handle g_OnGrenadeSaved = INVALID_HANDLE;
Handle g_OnPracticeModeDisabled = INVALID_HANDLE;
Handle g_OnPracticeModeEnabled = INVALID_HANDLE;

bool g_ClientButtonsInUse[MAXPLAYERS + 1] = {false, ...};

#include "practicemode/grenade_iterators.sp"

#include "practicemode/backups.sp"
#include "practicemode/bots.sp"
#include "practicemode/bots_menu.sp"
#include "practicemode/bots_utils.sp"

#include "practicemode/demos.sp"
#include "practicemode/demos_data.sp"
#include "practicemode/demos_menu.sp"
#include "practicemode/demos_utils.sp"

#include "practicemode/retakes.sp"
#include "practicemode/retakes_editor.sp"
#include "practicemode/retakes_data.sp"
#include "practicemode/retakes_menu.sp"

#include "practicemode/crossfire.sp"
#include "practicemode/crossfire_editor.sp"
#include "practicemode/crossfire_data.sp"
#include "practicemode/crossfire_menu.sp"

#include "practicemode/dev_entries.sp"

#include "practicemode/commands.sp"

#include "practicemode/grenade_commands.sp"
#include "practicemode/grenade_filters.sp"
#include "practicemode/grenade_menus.sp"
#include "practicemode/grenade_utils.sp"
// #include "practicemode/grenade_accuracy.sp"
#include "practicemode/grenade_hologram.sp"
#include "practicemode/grenade_prediction.sp"
#include "practicemode/learn.sp"

#include "practicemode/natives.sp"
// #include "practicemode/pugsetup_integration.sp"
#include "practicemode/spawns.sp"
#include "practicemode/breakables.sp"
#include "practicemode/afk_manager.sp"
#include "practicemode/commands_blocker.sp"

#include "practicemode/database.sp"

public Plugin myinfo = {
  name = "Practicemode Lite",
  author = "sergio",
  description = "",
  version = PLUGIN_VERSION,
  url = "https://steamcommunity.com/profiles/76561199016822889/"
};

public void OnPluginStart() {
  LoadTranslations("common.phrases");
  LoadTranslations("practicemode.phrases");
  g_InPracticeMode = false;
  AddCommandListener(Command_TeamJoin, "jointeam"); // (FIX) WHY?
  AddCommandListener(Command_Noclip, "noclip");
  AddCommandListener(Command_SetPos, "setpos");
  AddCommandListener(Command_ToggleBuyMenu, "open_buymenu");
  AddCommandListener(Command_ToggleBuyMenu, "close_buymenu");

  // Forwards
  g_OnGrenadeSaved = CreateGlobalForward("PM_OnGrenadeSaved", ET_Hook, Param_Cell,
                                         Param_Array, Param_Array, Param_String);
  g_OnPracticeModeDisabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
  g_OnPracticeModeEnabled = CreateGlobalForward("PM_OnPracticeModeDisabled", ET_Ignore);

  // Setup stuff for grenade history
  HookEvent("weapon_fire", Event_WeaponFired);
  HookEvent("flashbang_detonate", Event_FlashDetonate);
  HookEvent("smokegrenade_detonate", GrenadeDetonateTimerHelper);
  HookEvent("hegrenade_detonate", GrenadeDetonateTimerHelper);
  HookEvent("decoy_started", GrenadeDetonateTimerHelper);
  HookEvent("player_blind", Event_PlayerBlind);

  if (g_db == null) {
    Database.Connect(SQLConnectCallback, "storage-local");
  }

  for (int i = 0; i <= MaxClients; i++) {
    g_GrenadeHistoryPositions[i] = new ArrayList(3);
    g_GrenadeHistoryAngles[i] = new ArrayList(3);
    g_ClientGrenadeThrowTimes[i] = new ArrayList(3);
    g_ClientBots[i] = new ArrayList();
  }

  {    
    RegConsoleCmd("sm_practicesetup", Command_GivePracticeSetupMenu);
    PM_AddChatAlias(".setup", "sm_practicesetup");

    RegConsoleCmd("sm_practicemap", Command_Map);
    PM_AddChatAlias(".map", "sm_practicemap");

    RegConsoleCmd("sm_practicekick", Command_Kick);
    PM_AddChatAlias(".kick", "sm_practicekick");

    RegConsoleCmd("sm_helpinfo", Command_GiveHelpInfo);
    PM_AddChatAlias(".help", "sm_helpinfo");
  }

  RegAdminCmd("sm_exitpractice", Command_ExitPracticeMode, ADMFLAG_CHANGEMAP,
              "Salir del modo practica");

  // Grenade history commands
  {
    RegConsoleCmd("sm_backall", Command_BackAll);
    PM_AddChatAlias(".back", "sm_backall");

    RegConsoleCmd("sm_nextall", Command_NextAll);
    PM_AddChatAlias(".next", "sm_nextall");

    RegConsoleCmd("sm_lastgrenade", Command_LastGrenade);
    PM_AddChatAlias(".last", "sm_lastgrenade");
  }

  // csutils powered nade stuff.
  {
    RegConsoleCmd("sm_throw", Command_Throw);
    PM_AddChatAlias(".throw", "sm_throw");
    PM_AddChatAlias(".rethrow", "sm_throw");
  }

  // Spawns.
  {
    RegConsoleCmd("sm_gotospawn", Command_GotoSpawn);
    PM_AddChatAlias(".spawn", "sm_gotospawn");
    PM_AddChatAlias(".spawns", "sm_gotospawn");

    RegConsoleCmd("sm_gotoctspawn", Command_GotoCTSpawn);
    PM_AddChatAlias(".ctspawn", "sm_gotoctspawn");

    RegConsoleCmd("sm_gototspawn", Command_GotoTSpawn);
    PM_AddChatAlias(".tspawn", "sm_gototspawn");
  }

  // Menus
  {
    RegConsoleCmd("sm_botsmenu", Command_BotsMenu);
    PM_AddChatAlias(".bots", "sm_botsmenu");

    RegConsoleCmd("sm_bot", Command_Bot);
    PM_AddChatAlias(".bot", "sm_bot");

    RegConsoleCmd("sm_nadesmenu", Command_NadesMenu);
    PM_AddChatAlias(".nades", "sm_nadesmenu");
    PM_AddChatAlias(".grenades", "sm_nadesmenu");
    PM_AddChatAlias(".smokes", "sm_nadesmenu");
  }

  // Bot commands
  {
    RegConsoleCmd("sm_removeallbots", Command_RemoveAllBots);
    PM_AddChatAlias(".nobots", "sm_removeallbots");

    RegConsoleCmd("sm_prueba", FUNCION_PRUEBA);
    PM_AddChatAlias(".prueba", "sm_prueba");
  }

  // // Bot replay commands
  // {
  //   RegConsoleCmd("sm_replay", Command_Replay);
  //   PM_AddChatAlias(".replay", "sm_replay");

  //   RegConsoleCmd("sm_replays", Command_Replays);
  //   PM_AddChatAlias(".replays", "sm_replays");

  //   RegConsoleCmd("sm_replaymode", CommandToggleReplayMode);
  //   PM_AddChatAlias(".versus", "sm_replaymode");
  //   PM_AddChatAlias(".replaymode", "sm_replaymode");

  //   RegConsoleCmd("sm_pausemode", CommandTogglePauseMode);
  //   PM_AddChatAlias(".pause", "sm_pausemode");

  //   RegConsoleCmd("sm_namereplay", Command_NameReplay);
  //   PM_AddChatAlias(".namereplay", "sm_namereplay");

  //   RegConsoleCmd("sm_namerole", Command_NameRole);
  //   PM_AddChatAlias(".namerole", "sm_namerole");

  //   RegConsoleCmd("sm_cancel", Command_Cancel);
  //   PM_AddChatAlias(".cancel", "sm_cancel");

  //   RegConsoleCmd("sm_finishrecording", Command_FinishRecording);
  //   PM_AddChatAlias(".finish", "sm_finishrecording");

  //   RegConsoleCmd("sm_playrecording", Command_PlayRecording);
  //   PM_AddChatAlias(".play", "sm_playrecording");
  // }

  // Demo commands
  {
    RegConsoleCmd("sm_demo", Command_Demos);
    PM_AddChatAlias(".demo", "sm_demo");
    PM_AddChatAlias(".demos", "sm_demo");

    RegConsoleCmd("sm_testdemo", Command_TestDemo);
    PM_AddChatAlias(".testdemo", "sm_testdemo");

    // RegConsoleCmd("sm_demomode", CommandToggleReplayMode);
    // PM_AddChatAlias(".versus", "sm_demomode");
    // PM_AddChatAlias(".replaymode", "sm_demomode");

    // RegConsoleCmd("sm_pausemode", CommandTogglePauseMode);
    // PM_AddChatAlias(".pause", "sm_pausemode");

    RegConsoleCmd("sm_cancel", Command_DemoCancel);
    PM_AddChatAlias(".cancel", "sm_cancel");

    RegConsoleCmd("sm_finishrecording", Command_FinishRecordingDemo);
    PM_AddChatAlias(".finish", "sm_finishrecording");
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
  }

  // // Learn commands
  // {
  //   RegConsoleCmd("sm_learn", Command_Learn);
  //   PM_AddChatAlias(".learn", "sm_learn");

  //   RegConsoleCmd("sm_skip", Command_Skip);
  //   PM_AddChatAlias(".skip", "sm_skip");

  //   RegConsoleCmd("sm_stoplearn", Command_StopLearn);
  //   PM_AddChatAlias(".stoplearn", "sm_stoplearn");
  //   PM_AddChatAlias(".stoplearning", "sm_stoplearn");
    
  //   RegConsoleCmd("sm_show", Command_Show);
  //   PM_AddChatAlias(".show", "sm_show");
  // }

  // Retakes commands
  {
    RegConsoleCmd("sm_retakes_editormenu", Command_RetakesEditorMenu);
    PM_AddChatAlias(".editretakes", "sm_retakes_editormenu");

    RegConsoleCmd("sm_retakes_setupmenu", Command_RetakesSetupMenu);
    PM_AddChatAlias(".retakes", "sm_retakes_setupmenu");
    PM_AddChatAlias(".retake", "sm_retakes_setupmenu");
  }
  
  // Crossfire commands
  {
    RegConsoleCmd("sm_crossfires_editormenu", Command_CrossfiresEditorMenu);
    PM_AddChatAlias(".editcrossfires", "sm_crossfires_editormenu");

    RegConsoleCmd("sm_crossfires_setupmenu", Command_CrossfiresSetupMenu);
    PM_AddChatAlias(".crossfires", "sm_crossfires_setupmenu");
    PM_AddChatAlias(".crossfire", "sm_crossfires_setupmenu");
  }

  // Other commands
  {
    RegConsoleCmd("sm_testflash", Command_TestFlash);
    PM_AddChatAlias(".flash", "sm_testflash");

    RegConsoleCmd("sm_noflash", Command_NoFlash);
    PM_AddChatAlias(".noflash", "sm_noflash");

    // TODO: A timer menu may be more accesible to users, as the number of timer types continues to
    // increase...
    RegConsoleCmd("sm_time", Command_Time);
    PM_AddChatAlias(".timer", "sm_time");

    RegConsoleCmd("sm_time2", Command_Time2);
    PM_AddChatAlias(".timer2", "sm_time2");

    RegConsoleCmd("sm_countdown", Command_CountDown);
    PM_AddChatAlias(".countdown", "sm_countdown");

    RegConsoleCmd("sm_clearnades", Command_ClearNades);
    PM_AddChatAlias(".clear", "sm_clearnades");

    RegConsoleCmd("sm_clearmap", Command_ClearMap);
    PM_AddChatAlias(".clearmap", "sm_clearmap");
    PM_AddChatAlias(".cleanmap", "sm_clearmap");

    RegConsoleCmd("sm_stopall", Command_StopAll);
    PM_AddChatAlias(".stop", "sm_stopall");

    RegConsoleCmd("sm_dryrun", Command_DryRun);
    PM_AddChatAlias(".dry", "sm_dryrun");
    PM_AddChatAlias(".dryrun", "sm_dryrun");

    RegConsoleCmd("sm_god", Command_God);
    PM_AddChatAlias(".god", "sm_god");
    
    RegConsoleCmd("sm_break", Command_Break);
    PM_AddChatAlias(".break", "sm_break");

    RegConsoleCmd("sm_rr", Command_Restart);
    PM_AddChatAlias(".rr", "sm_rr");
    PM_AddChatAlias(".restart", "sm_rr");
  }
      
  HudSync = CreateHudSynchronizer();
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

  // New cvars we don't want saved in the autoexec'd file
  g_InfiniteMoneyCvar = CreateConVar("sm_infinite_money", "0",
                                     "Whether clients recieve infinite money", FCVAR_DONTRECORD);
  g_AllowNoclipCvar =
      CreateConVar("sm_allow_noclip", "1",
                   "Whether players may use .noclip in chat to toggle noclip", FCVAR_DONTRECORD);

  g_PatchGrenadeTrajectoryCvar =
      CreateConVar("sm_patch_grenade_trajectory_cvar", "1",
                   "Whether the plugin patches sv_grenade_trajectory with its own grenade trails");
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

  g_Spawns = new ArrayList(6); //spawn ent, trigger ent, 4 beams
  g_EnabledHoloNadeAuth = new ArrayList(AUTH_LENGTH);

  // Remove cheats so sv_cheats isn't required for this:
  RemoveCvarFlag(g_GrenadeTrajectoryCvar, FCVAR_CHEAT);

  AutoExecConfig(true, "practicemode");
  ServerCommand("exec practicemode.cfg");

  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_hurt", Event_BotDamageDealtEvent, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("round_freeze_end", Event_FreezeEnd);
  HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
  HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
  HookUserMessage(GetUserMessageId("SayText2"), Hook_SayText2, true);

  g_CSUtilsLoaded = LibraryExists("csutils");

  // why am i killing them
  // CreateTimer(1.0, Timer_CleanupLivingBots, _, TIMER_REPEAT);

  CommandsBlocker_PluginStart();
  Demos_PluginStart();
  HoloNade_PluginStart();
  // GrenadeAccuracy_PluginStart();
  Breakables_PluginStart();
  AfkManager_PluginStart();
  Retakes_PluginStart();
  Crossfire_PluginStart();
  DevEntries_PluginStart();
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  UpdateHoloNadeEntities();
  UpdateHoloSpawnEntities();
  if (g_InRetakeMode) {
    Event_Retakes_RoundStart(event, name, dontBroadcast);
  }
  return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_InRetakeMode) {
    Event_Retakes_RoundEnd(event, name, dontBroadcast);
  }
  return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsPracticeBot(client)) {
      SetEventBroadcast(event, true);
      return Plugin_Continue;
    }
    return Plugin_Continue;
}

public Action Hook_SayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init) {
    char[] sMessage = new char[24];
    if(GetUserMessageType() == UM_Protobuf) {
        Protobuf pbmsg = msg;
        pbmsg.ReadString("msg_name", sMessage, 24);
    } else {
        BfRead bfmsg = msg;
        bfmsg.ReadByte();
        bfmsg.ReadByte();
        bfmsg.ReadString(sMessage, 24, false);
    }
    if(StrEqual(sMessage, "#Cstrike_Name_Change")) {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

// public Action CommandTogglePauseMode(int client, int args) {
//   if (!g_InPracticeMode) {
//       return Plugin_Handled;
//   }
//   if (!g_InBotReplayMode || !IsReplayPlaying()) {
//     PM_Message(client, "Empieza una Demo primero!");
//     return Plugin_Handled;
//   }
//   ServerCommand("botmimictoggle_pausemode");
//   pauseMode = !pauseMode;
//   PM_Message(client, "Estado de repetición cambiado a: %s", !pauseMode ? "jugando" : "pausado");
//   if (pauseMode) {
//       GrenadeReplay_PauseGrenades();
//   } else {
//       GrenadeReplay_ResumeGrenades();
//   }
//   return Plugin_Handled;
// }

// public void GrenadeReplay_PauseGrenades() {
//   int lastEnt = GetMaxEntities();
//   for (int entity = MaxClients + 1; entity <= lastEnt; entity++) {
//     if (!IsValidEntity(entity)) {
//         continue;
//     }
//     char classnameEnt[64];
//     GetEntityClassname(entity, classnameEnt, sizeof(classnameEnt));
//     if (IsGrenadeProjectile(classnameEnt)) {
//       int GrenadeEntity = GetEntProp(entity, Prop_Data, "m_iTeamNum");
//       if (ExplodeNadeTimer[GrenadeEntity] != INVALID_HANDLE) {
//           KillTimer(ExplodeNadeTimer[GrenadeEntity]);
//           ExplodeNadeTimer[GrenadeEntity] = INVALID_HANDLE;
//       }
//       int client = Entity_GetOwner(entity);
//       if(!IsReplayBot(client)){
//           continue;
//       }
//       g_ReplayGrenadeLastPausedTime = GetEngineTime();
//       SetEntityMoveType(entity, MOVETYPE_NONE);
//       SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
//     }
//   } 
// }

// public void GrenadeReplay_ResumeGrenades() {
//   int lastEnt = GetMaxEntities();
//   for (int entity = MaxClients + 1; entity <= lastEnt; entity++) {
//     if (!IsValidEntity(entity)) {
//       continue;
//     }
//     char classnameEnt[64];
//     GetEntityClassname(entity, classnameEnt, sizeof(classnameEnt));
//     if (IsGrenadeProjectile(classnameEnt)) {
//       int client = Entity_GetOwner(entity);
//       if(!IsReplayBot(client)){
//         continue;
//       }
//       SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
//       if(GrenadeFromProjectileName(classnameEnt) == GrenadeType_Smoke || GrenadeFromProjectileName(classnameEnt) == GrenadeType_Decoy) {
//         SetEntProp(entity, Prop_Data, "m_nNextThinkTick", 1);
//         continue;
//       } 
//       else {
//         int GrenadeEntity = GetEntProp(entity, Prop_Data, "m_iTeamNum");
//         g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] = g_ReplayGrenadeLastResumedTime[GrenadeEntity];
//         if(g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] <= 0.0) {
//           g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] = g_ClientReplayGrenadeThrowTime[GrenadeEntity];
//         }
//         g_ReplayGrenadeLastResumedTime[GrenadeEntity] = GetEngineTime();
//         g_TiempoRecorrido[GrenadeEntity] += (g_ReplayGrenadeLastPausedTime - g_ReplayGrenadeLastLastResumedTime[GrenadeEntity]);
//         if(GrenadeFromProjectileName(classnameEnt) == GrenadeType_Flash || GrenadeFromProjectileName(classnameEnt) == GrenadeType_HE) {
//           float RemainingTime = GRENADE_DETONATE_FLASH_TIME - g_TiempoRecorrido[GrenadeEntity];
//           ExplodeNadeTimer[GrenadeEntity] = CreateTimer(RemainingTime, Timer_ForceExplodeNade, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
//         } else {
//           float RemainingTime = GRENADE_DETONATE_MOLOTOV_TIME - g_TiempoRecorrido[GrenadeEntity];
//           ExplodeNadeTimer[GrenadeEntity] = CreateTimer(RemainingTime, Timer_ForceExplodeNade, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
//         }
//       }
//     }
//   }
// }

// public Action Timer_ForceExplodeNade(Handle timer, int ref) {
//   int entity = EntRefToEntIndex(ref);
//   if(entity != -1) {
//     int GrenadeEntity = GetEntProp(entity, Prop_Data, "m_iTeamNum");
//     g_TiempoRecorrido[GrenadeEntity] = 0.0;
//     g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] = -1.0;
//     g_ReplayGrenadeLastResumedTime[GrenadeEntity] = -1.0;
//     SetEntProp(entity, Prop_Data, "m_nNextThinkTick", 1);
//     SDKHooks_TakeDamage(entity, entity, entity, 1.0);
//     ExplodeNadeTimer[GrenadeEntity] = INVALID_HANDLE;
//   }
//   return Plugin_Handled;
// }

public void OnPluginEnd() {
  OnMapEnd();
}

public void OnLibraryAdded(const char[] name) {
  g_CSUtilsLoaded = LibraryExists("csutils");
  g_BotMimicLoaded = LibraryExists("botmimic");
}

public void OnLibraryRemoved(const char[] name) {
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
    if (g_PracticeSetupClient == -2) {
      if (IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T) {
        ServerCommand("bot_kick");
        ServerCommand("mp_warmup_end");
        PrintToServer("Give Setup to Client %d", client);
        g_PracticeSetupClient = client;
        PracticeSetupMenu(client);
        ShowHelpInfo(client);
      } else {
        // Fix so when adding the first bot the match doesnt restart
        ServerCommand("mp_restartgame 1");
        ServerCommand("bot_add_ct");
        ServerCommand("bot_add_t");
      }
    }
  } else if (IsPMBot(client)) { //|| IsDemoBot(client)
    if (g_GlowPMBotsCvar.IntValue != 0) {
      RemoveSkin(client);
      CreateGlow(client);
    }
    if (IsPMBot(client)) {
      GiveBotParams(client);
    }
  }

  // TODO: move this elsewhere and save it properly.
  if (g_InBotDemoMode && g_BotMimicLoaded && IsDemoBot(client)) {
    Client_SetArmor(client, 100);
    SetEntData(client, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
  }

  return Plugin_Continue;
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
  g_LastGrenadeType[client] = GrenadeType_None;
  g_LastGrenadeEntity[client] = -1;
  g_CurrentEditingDemoRole[client] = -1;
  g_SelectedDemoId[client] = "";
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
  ServerCommand("exec practicemode.cfg");
  // g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
  g_PredictTrail = PrecacheModel("sprites/laserbeam.spr");
  g_BeamSprite = PrecacheModel("materials/sprites/white.vmt");
  PrecacheModel("models/chicken/festive_egg.mdl");
  PrecacheModel("models/error.mdl");
  PrecacheParticle("silvershot_string_lights_02");

  EnforceDirectoryExists("data/practicemode");
  EnforceDirectoryExists("data/practicemode/bots");
  EnforceDirectoryExists("data/practicemode/bots/backups");
  EnforceDirectoryExists("data/practicemode/grenades");
  EnforceDirectoryExists("data/practicemode/grenades/backups");
  EnforceDirectoryExists("data/practicemode/retakes");
  EnforceDirectoryExists("data/practicemode/retakes/backups");
  EnforceDirectoryExists("data/practicemode/crossfires");
  EnforceDirectoryExists("data/practicemode/crossfires/backups");
  EnforceDirectoryExists("data/practicemode/entries");
  EnforceDirectoryExists("data/practicemode/entries/backups");
  EnforceDirectoryExists("data/practicemode/demos");
  EnforceDirectoryExists("data/practicemode/demos/backups");

  // This supports backwards compatability for grenades saved in the old location
  // data/practicemode_grenades. The data is transferred to the new
  // location if they are read from the legacy location.
  char legacyDir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, legacyDir, sizeof(legacyDir), "data/practicemode_grenades");

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  // DATABASE
  GetCleanMapName(g_dbMap, sizeof(g_dbMap));

  // // char legacyFile[PLATFORM_MAX_PATH];
  // // Format(legacyFile, sizeof(legacyFile), "%s/%s.cfg", legacyDir, map);

  // // BuildPath(Path_SM, g_GrenadeLocationsFile, sizeof(g_GrenadeLocationsFile),
  // //           "data/practicemode/grenades/%s.cfg", map);

  // // if (!FileExists(g_GrenadeLocationsFile) && FileExists(legacyFile)) {
  // //   PrintToServer("Moving legacy grenade data from %s to %s", legacyFile, g_GrenadeLocationsFile);
  // //   g_GrenadeLocationsKv = new KeyValues("Grenades");
  // //   g_GrenadeLocationsKv.ImportFromFile(legacyFile);
  // //   g_UpdatedGrenadeKv = true;
  // // } else {
  // //   g_GrenadeLocationsKv = new KeyValues("Grenades");
  // //   // g_GrenadeLocationsKv.SetEscapeSequences(true); // Avoid fatals from special chars in user data
  // //   g_GrenadeLocationsKv.ImportFromFile(g_GrenadeLocationsFile);
  // //   g_UpdatedGrenadeKv = false;
  // // }

  // // MaybeCorrectGrenadeIds();

  Spawns_MapStart();
  Demos_MapStart();
  HoloNade_MapStart();
  // GrenadeAccuracy_MapStart();
  Breakables_MapStart();
  AfkManager_MapStart();
  Retakes_MapStart();
  Crossfires_MapStart();
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
    PrintToServer("%s was unloaded and moved to %s", legacyPluginFile, disabledLegacyPluginName);
  }

  CheckAutoStart();
}

public void OnGrenadeKvMutate() {
  HoloNade_GrenadeKvMutate();
}

public void CheckAutoStart() {
  // Autostart practicemode if enabled.
  if (g_AutostartCvar.IntValue != 0 && !g_InPracticeMode) {
    LaunchPracticeMode();
  }
}

public void OnClientDisconnect(int client) {
  // // MaybeWriteNewGrenadeData();
  if (IsPracticeBot(client)) {
    SetNotPracticeBot(client);
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

  // Reset Variable
  g_ClientButtonsInUse[client] = false;

  AfkManager_ClientDisconnect(client);
  // Learn_ClientDisconnect(client);
}

public void OnMapEnd() {
  // // MaybeWriteNewGrenadeData();

  if (g_InPracticeMode) {
    ExitPracticeMode();
  }

  Spawns_MapEnd();
  Demos_MapEnd();
  HoloNade_MapEnd();
  Retakes_MapEnd();
  Crossfires_MapEnd();
  // // delete g_GrenadeLocationsKv;
}

// // public void MaybeWriteNewGrenadeData() {
// //   if (g_UpdatedGrenadeKv) {
// //     g_GrenadeLocationsKv.Rewind();
// //     BackupFiles("grenades");
// //     DeleteFile(g_GrenadeLocationsFile);
// //     if (!g_GrenadeLocationsKv.ExportToFile(g_GrenadeLocationsFile)) {
// //       PrintToServer("[MaybeWriteNewGrenadeData]Failed to write grenade data to %s", g_GrenadeLocationsFile);
// //     }
// //     g_UpdatedGrenadeKv = false;
// //   }
// // }

public void OnClientPutInServer(int client) {
  if (!IsPlayer(client)) {
    return;
  }
  DB_GetPlayerData(client);
  HoloNade_ClientPutInServer(client);
}

public Action FUNCION_PRUEBA(int client, int args) {
  if (args >= 1) {
    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));
    int index = Client_GetWeapon(client, arg);
    PM_Message(client, "prueba: %d", index);
    // int ent = CreateEntityByName("prop_dynamic_override");
    // if (ent > 0) {
    //   SetEntityModel(ent, arg);
    //   float fOrigin[3];
    //   GetClientAbsOrigin(client, fOrigin);
    //   if (DispatchSpawn(ent)) {
    //     TeleportEntity(ent, fOrigin, NULL_VECTOR, NULL_VECTOR);
    //     PrintToChatAll("yes");
    //   }
    // }
  }
  return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
                      int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed,
                      int mouse[2]) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  if (!IsPlayer(client)) {
    if (IsPMBot(client)) {
      return PMBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    } else if (g_IsNadeDemoBot[client]) {
      return NadeDemoBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    } else if (IsRetakeBot(client)) {
      return RetakeBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    } else if (IsCrossfireBot(client)) {
      return CrossfireBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    }
    return Plugin_Continue;
  }

  if (g_InRetakeMode || g_InCrossfireMode) {
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

  if (!IsPlayerAlive(client)) {
    return Plugin_Continue;
  }

  // Interaction
  if ((buttons & IN_USE) && !g_ClientButtonsInUse[client]) {
    g_ClientButtonsInUse[client] = true;
    // Grenade Hologram
    float eyeOrigin[3], eyeForward[3], eyeEnd[3];
    GetClientEyePosition(client, eyeOrigin);
    GetClientEyeAngles(client, eyeForward);
    GetAngleVectors(eyeForward, eyeForward, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(eyeForward, eyeForward);
    ScaleVector(eyeForward, 80.0); //interacting_distance
    AddVectors(eyeOrigin, eyeForward, eyeEnd);
    float entOrigin[3];
    int holoNadeIndex = GetNearestNadeGroupIndex(eyeOrigin, entOrigin);
    if (PointInsideViewRange(entOrigin, eyeOrigin, eyeEnd)) {
      GiveNadeGroupMenu(client, holoNadeIndex);
      return Plugin_Continue;
    }
    // Spawn Entity
    if (GetCvarIntSafe("sm_holo_spawns") == 1) {
      ScaleVector(eyeForward, 3.0);
      AddVectors(eyeOrigin, eyeForward, eyeEnd);
      float entAngles[3];
      int spawnIndex = GetNearestSpawnEntsIndex(eyeOrigin, entOrigin, entAngles);
      if (PointInsideViewRange(entOrigin, eyeOrigin, eyeEnd)) {
        TeleportEntity(client, entOrigin, entAngles, ZERO_VECTOR);
        char spawnclassName[CLASS_LENGTH];
        int spawnEnt = g_Spawns.Get(spawnIndex, 0);
        if (IsValidEntity(spawnEnt)) {
          GetEntityClassname(g_Spawns.Get(spawnIndex, 0), spawnclassName, sizeof(spawnclassName));
          if (StrEqual(spawnclassName, "info_player_counterterrorist")) {
            PM_Message(client, "{ORANGE}%t: {GREEN}%d", "TeleportingToCTSpawn", client, spawnIndex + 1);
          } else {
            PM_Message(client, "{ORANGE}%t: {GREEN}%d", "TeleportingToTSpawn", client, spawnIndex + 1 - ctSpawnsLength);
          }
        }
        return Plugin_Continue;
      }
    }
  } else if (g_ClientButtonsInUse[client] && !(buttons & IN_USE)) {
    g_ClientButtonsInUse[client] = false;
  }
  
  char weaponName[64];
  GetClientWeapon(client, weaponName, sizeof(weaponName));

  if((StrContains(nadelist, weaponName, false) != -1)) {
    if(((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)) && !g_ClientPulledPin[client]) {
        GetClientAbsOrigin(client, g_LastGrenadePinPulledOrigin[client]);
        GetClientEyeAngles(client, g_LastGrenadePinPulledAngles[client]);
        g_ClientPulledPinButtons[client] = 0;
        g_ClientPulledPin[client] = true;
        // DEMOS
        if (!g_InBotDemoMode) { // && g_recordingNadeDemoStatus[client] == 0
          if (BotMimic_IsPlayerRecording(client)) {
            BotMimic_StopRecording(client, false); // delete
            g_recordingNadeDemoStatus[client] = 0;
          }
          char recordName[128];
          Format(recordName, sizeof(recordName), "player %N %s", client, weaponName);
          g_CurrentDemoRecordingStartTime[client] = GetGameTime();
          g_recordingNadeDemoStatus[client] = 1;
          g_DemoNadeData[client].Clear();
          BotMimic_StartRecording(client, recordName, "practicemode", _, 600);
        }
    } else if (g_ClientPulledPin[client] && !((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))) {
        g_ClientPulledPinButtons[client] |= buttons;
        g_ClientPulledPin[client] = false;
        // DEMOS
        if (g_recordingNadeDemoStatus[client]) {
          if (!g_InBotDemoMode && BotMimic_IsPlayerRecording(client)) {
            g_recordingNadeDemoStatus[client] = 2;
            CreateTimer(0.2, Timer_Botmimic_PauseRecording, GetClientSerial(client));
          }
        }
    }
    if (g_ClientPulledPin[client]) {
      float exxvel[3];
      Entity_GetAbsVelocity(client, exxvel);
      if (GetVectorDotProduct(exxvel, exxvel) <= 0.01) {
        g_ClientPulledPinButtons[client] = 0;
        GetClientAbsOrigin(client, g_LastGrenadePinPulledOrigin[client]);
        GetClientEyeAngles(client, g_LastGrenadePinPulledAngles[client]);
      } else {
        g_ClientPulledPinButtons[client] |= buttons;
      }
    }
  } else {
    // DEMOS
    if (g_recordingNadeDemoStatus[client] == 1) {
      if (!g_InBotDemoMode && BotMimic_IsPlayerRecording(client)) {
        g_recordingNadeDemoStatus[client] = 0;
        BotMimic_StopRecording(client, false); // delete
      }
    }
  }
  NadePrediction_PlayerRunCmd(client, buttons, weaponName);
  //HoloSpawn_PlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
  return Plugin_Continue;
}

static bool MovingButtons(int buttons) {
  return buttons & IN_FORWARD != 0 || buttons & IN_MOVELEFT != 0 || buttons & IN_MOVERIGHT != 0 ||
         buttons & IN_BACK != 0;
}

public Action Timer_Botmimic_PauseRecording(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (BotMimic_IsPlayerRecording(client)) {
    if (BotMimic_IsRecordingPaused(client)) {
      BotMimic_StopRecording(client, false); // delete
      PrintToServer("Error: Tried to Stop an already Stopped recording");
      return Plugin_Handled;
    }
    BotMimic_PauseRecording(client);
  }
  return Plugin_Handled;
}

// Stops Bots Joining When Changin Team
public Action Command_TeamJoin(int client, const char[] command, int argc) {
  if (!IsValidClient(client) || argc < 1)
    return Plugin_Handled;

  if (g_InCrossfireMode || g_InRetakeMode) {
    return Plugin_Handled;
  }

  if (g_InPracticeMode) {
    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team = StringToInt(arg);
    SwitchPlayerTeam(client, team);

    // // Since we force respawns off during bot demo, make teamswitches respawn players.
    // if (g_InBotDemoMode && team != CS_TEAM_SPECTATOR && team != CS_TEAM_NONE) {
    //   CS_RespawnPlayer(client);
    // }

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

public Action Command_ToggleBuyMenu(int client, const char[] command, int argsc) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }
  if (g_InDryMode) {
    return Plugin_Continue;
  }
  int maxMoney = GetCvarIntSafe("mp_maxmoney", 16000);
  if (g_InfiniteMoneyCvar.IntValue != 0) {
    if (IsPlayer(client)) {
      SetEntProp(client, Prop_Send, "m_iAccount", maxMoney);
    }
  }
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

  if (GetCvarIntSafe("sm_allow_noclip") == 0) {
    SetEntityMoveType(client, MOVETYPE_WALK);
    return;
  }

  // Stop recording if we are.
  if (g_BotMimicLoaded && g_InBotDemoMode) {
    FinishRecordingDemo(client, false);
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

public void LaunchPracticeMode() {
  ServerCommand("exec sourcemod/practicemode_start.cfg");

  g_InPracticeMode = true;
  ServerCommand("exec practicemode.cfg");
  SetConVarFloatSafe("mp_roundtime_defuse", 60.0);
  SetCvarIntSafe("mp_forcecamera", 2);
  SetCvarIntSafe("mp_radar_showall", 1);
  SetCvarIntSafe("sm_glow_pmbots", 1);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 1);
  SetCvarIntSafe("sv_infinite_ammo", 1);
  SetCvarIntSafe("sm_allow_noclip", 1);
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
  SetCvarIntSafe("sv_showimpacts", 1);
  SetCvarIntSafe("sm_holo_spawns", 1);
  SetCvarIntSafe("sm_bot_collision", 0);

  HoloNade_LaunchPracticeMode();

  // PM_MessageToAll("Modo Práctica esta activado.");
  Call_StartForward(g_OnPracticeModeEnabled);
  Call_Finish();
}

public void ExitPracticeMode() {
  if (!g_InPracticeMode) {
    return;
  }

  Call_StartForward(g_OnPracticeModeDisabled);
  Call_Finish();

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && IsFakeClient(i) && IsPracticeBot(i)) {
      KickClient(i);
      SetNotPracticeBot(i);
    }
  }

  SetCvarIntSafe("mp_startmoney", 800);
  SetConVarFloatSafe("mp_roundtime_defuse", 1.92);
  SetCvarIntSafe("mp_freezetime", g_DryRunFreezeTimeCvar.IntValue);
  SetCvarIntSafe("mp_radar_showall", 0);
  SetCvarIntSafe("sm_glow_pmbots", 0);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 0);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("sv_infinite_ammo", 2);
  SetCvarIntSafe("sm_allow_noclip", 0);
  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  // SetCvarIntSafe("mp_buy_anywhere", 0);
  // SetCvarIntSafe("mp_buytime", 40);
  SetCvarIntSafe("sv_showimpacts", 0);
  SetCvarIntSafe("sm_holo_spawns", 0);
  SetCvarIntSafe("sm_bot_collision", 1);
  
  SetConVarStringSafe("sv_password", "");

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
  ServerCommand("exec sourcemod/practicemode_end.cfg");
  // PM_MessageToAll("Modo Práctica esta desactivado.");
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
      g_ClientGrenadeThrowTimes[client].Set(index, 0, 2);
      SDKHook(entity, SDKHook_StartTouch, GrenadeTouch);
    }
    if (IsDemoBot(client) && g_InPracticeMode &&
    (GrenadeFromProjectileName(className) != GrenadeType_None || GrenadeFromProjectileName(className) != GrenadeType_Smoke)) {
      g_currentDemoGrenade++;
      SetEntProp(entity, Prop_Data, "m_iTeamNum", g_currentDemoGrenade);
      g_ClientDemoGrenadeThrowTime[g_currentDemoGrenade] = GetEngineTime();
    }

    if (IsValidEntity(entity)) {
      if (g_GrenadeTrajectoryCvar.IntValue != 0 && g_PatchGrenadeTrajectoryCvar.IntValue != 0) {
        // Send a temp ent beam that follows the grenade entity to all other clients.
        for (int i = 1; i <= MaxClients; i++) {
          if (!IsClientConnected(i) || !IsClientInGame(i)) {
            continue;
          }

          // Note: the technique using temporary entities is taken from InternetBully's NadeTails
          // plugin which you can find at https://forums.alliedmods.net/showthread.php?t=240668
          float time = (GetClientTeam(i) == CS_TEAM_SPECTATOR) ? g_GrenadeSpecTimeCvar.FloatValue
                                                               : g_GrenadeTimeCvar.FloatValue;

          // int colors[4];
          // colors[0] = GetRandomInt(0, 255);
          // colors[1] = GetRandomInt(0, 255);
          // colors[2] = GetRandomInt(0, 255);
          // colors[3] = 255;

          TE_SetupBeamFollow(entity, g_BeamSprite, 0, time, g_GrenadeThicknessCvar.FloatValue * 5,
                             g_GrenadeThicknessCvar.FloatValue * 5, 1, { 0, 255, 255, 255 });
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
      PM_Message(i, "{PURPLE}---------------");
      PM_Message(i, "{ORANGE}%t: %N", "BlindedPlayer", i, victim);
      float accuracy = GetFlashDuration(victim)/5.21*100;
      accuracy > 100.0 ? (accuracy=100.0) : accuracy;
      PM_Message(i, "%t: %s%.1f%%", "FlashPrecision", i, T_CB, accuracy);
      PM_Message(i, "%t: %s%.1f{NORMAL}s", "FlashDuration", i, T_CB, GetFlashDuration(victim));
      PM_Message(i, "{PURPLE}---------------");
      break;
    }
  }

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

public Action GrenadeTouch(int entity, int other) {
  int client = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
  if (IsPlayer(client)) {
    for (int i = 0; i < g_ClientGrenadeThrowTimes[client].Length; i++) {
      int ref = g_ClientGrenadeThrowTimes[client].Get(i, 0);
      if (EntRefToEntIndex(ref) == entity) {
        g_ClientGrenadeThrowTimes[client].Set(i, g_ClientGrenadeThrowTimes[client].Get(i, 2) + 1, 2);
      }
    }
  } else {
    SDKUnhook(entity, SDKHook_StartTouch, GrenadeTouch);
  }
  return Plugin_Continue;
}

public Action GrenadeDetonateTimerHelper(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  int entity = event.GetInt("entityid");

  if (IsPlayer(client)) {
    for (int i = 0; i < g_ClientGrenadeThrowTimes[client].Length; i++) {
      int ref = g_ClientGrenadeThrowTimes[client].Get(i, 0);
      if (EntRefToEntIndex(ref) == entity) {
        float dt = GetEngineTime() - view_as<float>(g_ClientGrenadeThrowTimes[client].Get(i, 1));
        int bounces = g_ClientGrenadeThrowTimes[client].Get(i, 2);
        g_ClientGrenadeThrowTimes[client].Erase(i);
        char grenadeName[CLASS_LENGTH];
        GetEntityClassname(entity, grenadeName, sizeof(grenadeName));
        GrenadeType grenadeType = GrenadeTypeFromWeapon(client, grenadeName);
        GrenadeTypeString(grenadeType, grenadeName, sizeof(grenadeName));
        UpperString(grenadeName);
        PM_Message(client, "{ORANGE}%t (%s): %.1f segundos, %d rebotes", "AirTime", client, grenadeName, dt, bounces);
        if (grenadeType == GrenadeType_Smoke) {
          ForceGlow(entity);
        }
        break;
      }
    }
  }
  return Plugin_Continue;
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

public Action Timer_FakeGrenadeBack(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (g_InPracticeMode && IsPlayer(client)) {
    FakeClientCommand(client, "sm_lastgrenade");
  }
  return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  int victim = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(victim)) {
    if (g_InRetakeMode) {
      int index = g_RetakePlayers.FindValue(victim);
      if (index != -1) {
        g_RetakeDeathPlayersCount++;
        if (g_RetakeDeathPlayersCount == g_RetakePlayers.Length) {
          EndSingleRetake(false);
        }
      }
    } else if (g_InCrossfireMode) {
      int index = g_CrossfirePlayers.FindValue(victim);
      if (index != -1) {
        g_CFireDeathPlayersCount++;
        if (g_CFireDeathPlayersCount == g_CrossfirePlayers.Length) {
          EndSingleCrossfire(false);
        }
      }
    } else {
      CreateTimer(1.5, Timer_RespawnClient, GetClientSerial(victim), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
  } else {
    if (IsPMBot(victim)) {
      return Event_PMBot_Death(victim, event, name, dontBroadcast);
    } else if (IsDemoBot(victim)) {
      return Event_DemoBot_Death(victim, event, name, dontBroadcast);
    } else if (IsRetakeBot(victim)) {
      return Event_RetakeBot_Death(victim, event, name, dontBroadcast);
    } else if (IsCrossfireBot(victim)) {
      return Event_CrossfireBot_Death(victim, event, name, dontBroadcast);
    }
  }
  return Plugin_Continue;
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
    }

    if (GetEntityMoveType(i) == MOVETYPE_NOCLIP) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
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

  if (StrEqual(chatCommand, ".menu")) {
    GivePracticeMenu(client);
    return;
  }

  char cleanArgs[128];
  strcopy(cleanArgs, sizeof(cleanArgs), sArgs);
  CleanMsgString(cleanArgs, sizeof(cleanArgs));
  if (g_WaitForSaveNade[client]) {
    g_WaitForSaveNade[client] = false;
    if (StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "{ORANGE}%t", "ActionCanceled", client);
    } else {
      SaveClientNade(client, cleanArgs);
    }
  } else if (g_WaitForServerPassword && client == g_PracticeSetupClient) {
    g_WaitForServerPassword = false;
    if (StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "{ORANGE}%t", "ActionCanceled", client);
    } else {
      SetConVarStringSafe("sv_password", cleanArgs);
      PM_Message(client, "%t \"{ORANGE}%s{NORMAL}\".", "PasswordChangedTo", client, cleanArgs);
    }
    PracticeSetupMenu(client);
  } else if(g_WaitForRetakeSave[client]) {
    g_WaitForRetakeSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "{ORANGE}%t", "ActionCanceled", client);
    } else {
      IntToString(GetRetakesNextId(), g_SelectedRetakeId, RETAKE_ID_LENGTH);
      SetRetakeName(g_SelectedRetakeId, cleanArgs);
      PM_Message(client, "{ORANGE}%t", "CreatedRetake", client, cleanArgs, g_SelectedRetakeId);
      SingleRetakeEditorMenu(client);
    }
  } else if(g_WaitForCrossfireSave[client]) {
    g_WaitForCrossfireSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "{ORANGE}%t", "ActionCanceled", client);
    } else {
      IntToString(GetCrossfiresNextId(), g_SelectedCrossfireId, CROSSFIRE_ID_LENGTH);
      SetCrossfireName(g_SelectedCrossfireId, cleanArgs);
      PM_Message(client, "{ORANGE}%t", "CreatedCrossfire", client, cleanArgs, g_SelectedCrossfireId);
      SingleCrossfireEditorMenu(client);
    }
  } else if (g_WaitForDemoSave[client]) {
    g_WaitForDemoSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "{ORANGE}%t", "ActionCanceled", client);
    } else {
      IntToString(GetDemosNextId(), g_SelectedDemoId[client], DEMO_ID_LENGTH);
      SetDemoName(g_SelectedDemoId[client], cleanArgs);
      PM_Message(client, "{ORANGE}%t", "CreatedDemo", client, cleanArgs, g_SelectedDemoId[client]);
      SingleDemoEditorMenu(client);
    }
  } else if (g_WaitForSingleDemoRoleName[client]) {
    g_WaitForSingleDemoRoleName[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "{ORANGE}%t", "ActionCanceled", client);
    } else {
      char demoRoleStr[DEMO_ID_LENGTH];
      IntToString(g_CurrentEditingDemoRole[client], demoRoleStr, sizeof(demoRoleStr));
      SetDemoRoleKVString(g_SelectedDemoId[client], demoRoleStr, "name", cleanArgs);
      PM_Message(client, "{ORANGE}%t", "NameChangedTo", client, cleanArgs);
      SingleDemoRoleMenu(client, g_CurrentEditingDemoRole[client]);
    }
  } else if (g_WaitForSingleDemoName[client]) {
    g_WaitForSingleDemoName[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "{ORANGE}%t", "ActionCanceled", client);
    } else {
      SetDemoName(g_SelectedDemoId[client], cleanArgs);
      PM_Message(client, "{ORANGE}%t", "NameChangedTo", client, cleanArgs);
      SingleDemoEditorMenu(client);
    }
  }
}

stock void CleanMsgString(char[] msg, int size) {
  ReplaceString(msg, size, "%", "％");
  StripQuotes(msg);
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

stock void PracticeSetupMenu(int client, int pos = 0) {
  Menu menu = new Menu(PracticeSetupMenuHandler);
  menu.SetTitle("%t", "Server_Settings");

  char buffer[128];
  GetCvarStringSafe("sv_password", buffer, sizeof(buffer));
  if (!StrEqual(buffer, "")) {
    Format(buffer, sizeof(buffer), "%t", "ServerAccessPass", client);
    menu.AddItem("password", buffer);
    Format(buffer, sizeof(buffer), "%t\n ", "ChangePassword", client);
    menu.AddItem("changepassword", buffer);
  } else {
    Format(buffer, sizeof(buffer), "%t", "ServerAccessNoPass", client);
    menu.AddItem("password", buffer);
    Format(buffer, sizeof(buffer), "%t\n ", "ChangePassword", client);
    menu.AddItem("changepassword", buffer, ITEMDRAW_DISABLED);
  }

  menu.AddItem("", "", ITEMDRAW_NOTEXT);
  menu.AddItem("", "", ITEMDRAW_NOTEXT);

  Format(buffer, sizeof(buffer), "%t", "ChangeMap", client);
  menu.AddItem("changemap", buffer);
  Format(buffer, sizeof(buffer), "%t", "KickPlayers", client);
  menu.AddItem("kickplayers", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_ShowImpacts", client,
  (GetCvarIntSafe("sv_showimpacts") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("showimpacts", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_InfiniteAmmo", client,
  (GetCvarIntSafe("sv_infinite_ammo") != 1) ? "Disabled" : "Enabled", client);
  menu.AddItem("infiniteammo", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_BotsWallhack", client,
  (GetCvarIntSafe("sm_glow_pmbots") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("glowbots", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_GrenadeTrajectory", client,
  (GetCvarIntSafe("sv_grenade_trajectory") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("grenadetrajectory", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_ShowSpawns", client,
  (GetCvarIntSafe("sm_holo_spawns") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("glowspawns", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_AllowNoclip", client,
  (GetCvarIntSafe("sm_allow_noclip") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("noclip", buffer);

  // Format(buffer, sizeof(buffer), "%t: %t", "Colisiones: ", client,
  // (GetCvarIntSafe("sm_bot_collision") == 0) ? "Disabled" : "Enabled", client);
  // menu.AddItem("collision", buffer);

  // menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;

  menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int PracticeSetupMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    int menuPos = 0;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "password")) {
      char SvPassword[MAX_PASSWORD_LENGTH];
      GetConVarString(FindConVar("sv_password"), SvPassword, sizeof(SvPassword));
      if (!StrEqual(SvPassword, "")) {
        SetConVarString(FindConVar("sv_password"), "");
      } else {
        PM_Message(client, "%t", "WriteInput", client, "la nueva contraseña");
        g_WaitForServerPassword = true;
      }
    } else if (StrEqual(buffer, "changepassword")) {
        PM_Message(client, "%t", "WriteInput", client, "la nueva contraseña");
        g_WaitForServerPassword = true;
    } else if (StrEqual(buffer, "kickplayers")) {
      Command_Kick(client, 0);
      return 0;
    } else if (StrEqual(buffer, "changemap")) {
      Command_Map(client, 0);
      return 0;
    } else {
      if (StrEqual(buffer, "showimpacts")) {
        (GetCvarIntSafe("sv_showimpacts") == 1)
        ? SetCvarIntSafe("sv_showimpacts", 0)
        : SetCvarIntSafe("sv_showimpacts", 1);
      }
      else if (StrEqual(buffer, "infiniteammo")) {
        (GetCvarIntSafe("sv_infinite_ammo") == 1)
        ? SetCvarIntSafe("sv_infinite_ammo", 2)
        : SetCvarIntSafe("sv_infinite_ammo", 1);
      }
      else if (StrEqual(buffer, "glowbots")) {
        (GetCvarIntSafe("sm_glow_pmbots") == 1)
        ? SetCvarIntSafe("sm_glow_pmbots", 0)
        : SetCvarIntSafe("sm_glow_pmbots", 1);
      }
      else if (StrEqual(buffer, "grenadetrajectory")) {
        (GetCvarIntSafe("sv_grenade_trajectory") == 1)
        ? SetCvarIntSafe("sv_grenade_trajectory", 0)
        : SetCvarIntSafe("sv_grenade_trajectory", 1);
      }
      else if (StrEqual(buffer, "glowspawns")) {
        (GetCvarIntSafe("sm_holo_spawns") == 1)
        ? SetCvarIntSafe("sm_holo_spawns", 0)
        : SetCvarIntSafe("sm_holo_spawns", 1);
      }
      else if (StrEqual(buffer, "noclip")) {
        (GetCvarIntSafe("sm_allow_noclip") == 1)
        ? SetCvarIntSafe("sm_allow_noclip", 0)
        : SetCvarIntSafe("sm_allow_noclip", 1);
      }
      else if (StrEqual(buffer, "collision")) {
        (GetCvarIntSafe("sm_bot_collision") == 1)
        ? SetCvarIntSafe("sm_bot_collision", 0)
        : SetCvarIntSafe("sm_bot_collision", 1);
      }
      menuPos = 6;
    }
    PracticeSetupMenu(client, menuPos);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void GivePracticeMenu(int client, int style = ITEMDRAW_DEFAULT) {
  Menu menu = new Menu(PracticeMenuHandler);
  menu.SetTitle("%t", "PracticeMenu", client);
  char displayStr[OPTION_NAME_LENGTH];
  Format(displayStr, sizeof(displayStr), "%t", "BotsMenu", client);
  menu.AddItem("bots_menu", displayStr);
  Format(displayStr, sizeof(displayStr), "%t\n ", "NadesMenu", client);
  menu.AddItem("nades_menu", displayStr);
  
  Format(displayStr, sizeof(displayStr), "%t\n ", "Help", client);
  menu.AddItem("help", displayStr);

  menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public int PracticeMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    
    if (StrEqual(buffer, "bots_menu")) {
      GiveBotsMenu(client);
    } else if (StrEqual(buffer, "nades_menu")) {
      GiveNadesMainMenu(client);
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
    char setupClientName[MAX_NAME_LENGTH];
    if (IsPlayer(g_PracticeSetupClient)) {
      GetClientName(g_PracticeSetupClient, setupClientName, MAX_NAME_LENGTH);
    }
    PM_Message(client, "{GREEN}.setup: {PURPLE}%t {ORANGE}(%s)", "Help_Setup", client, setupClientName);
    PM_Message(client, "{GREEN}.menu: {PURPLE}%t", "Help_Menu", client);
    PM_Message(client, "%t", "Help_Save", client);
    PM_Message(client, "{GREEN}.copy: {PURPLE}%t", "Help_Copy", client);
    PM_Message(client, "{GREEN}.throw: {PURPLE}%t", "Help_Throw", client);
    PM_Message(client, "{GREEN}.flash: {PURPLE}%t", "Help_Flash", client);
    PM_Message(client, "{GREEN}.last: {PURPLE}%t", "Help_Last", client);
    PM_Message(client, "{GREEN}.clear: {PURPLE}%t", "Help_Clear", client);
    PM_Message(client, "{GREEN}.clearmap/.cleanmap: {PURPLE}%t", "Help_ClearMap", client);
    PM_Message(client, "{GREEN}.map: {PURPLE}%t", "Help_Map", client);
    PM_Message(client, "{GREEN}.bots: {PURPLE}%t", "Help_Bots", client);
    PM_Message(client, "%t", "Help_Predict1", client);
    PM_Message(client, "%t", "Help_Predict2", client);
    PM_Message(client, "%t", "Help_Predict3", client);
    PM_Message(client, "%t", "Help_Predict4", client);
    PM_Message(client, "%t", "Help_Page", client);
  } else if (page == 2) {
    PM_Message(client, "%t", "Help_Back", client);
    PM_Message(client, "%t", "Help_Next", client);
    PM_Message(client, "%t", "Help_NoFlash", client);
    PM_Message(client, "%t", "Help_Timer", client);
    PM_Message(client, "%t", "Help_God", client);
    PM_Message(client, "%t", "Help_RR", client);
  }
}

public void CSU_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3],
                        const float velocity[3]) {
  g_LastGrenadeType[client] = grenadeType;
  g_LastGrenadeOrigin[client] = origin;
  g_LastGrenadeVelocity[client] = velocity;
  g_LastGrenadeDetonationOrigin[client] = view_as<float>({0.0, 0.0, 0.0});
  g_LastGrenadeEntity[client] = entity;
  Demos_OnThrowGrenade(client, entity, grenadeType, origin, velocity);
  // GrenadeAccuracy_OnThrowGrenade(client, entity);
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
  // GrenadeAccuracy_OnGrenadeExplode(client, currentEntity, grenade, grenadeDetonationOrigin);
  // Learn_OnGrenadeExplode(client, currentEntity, grenade, grenadeDetonationOrigin);
}
