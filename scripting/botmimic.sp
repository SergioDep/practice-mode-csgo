#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <smlib>
#include <botmimic>
#include "practicemode/util.sp"

#undef REQUIRE_EXTENSIONS
#include <dhooks>

#pragma newdecls required

#define PLUGIN_VERSION "2.1"

#define BM_MAGIC 0xdeadbeef

// New in 0x02: bookmarkCount and bookmarks list
#define BINARY_FORMAT_VERSION 0x02

// Path for the recordings to be saved.
#define DEFAULT_RECORD_FOLDER "data/botmimic/"

// Flags set in FramInfo.additionalFields to inform, that there's more info afterwards.
#define ADDFIELD_TP_ORIGIN (1<<0)
#define ADDFIELD_TP_ANGLES (1<<1)
#define ADDFIELD_TP_VEL (1<<2)

enum struct FrameInfo {
  int playerButtons;
  int playerImpulse;
  float actualVelocity[3];
  float predictedVelocity[3];
  float predictedAngles[2]; // Ignore roll
  CSWeaponID newWeapon;
  int playerSubtype;
  int playerSeed;
  int additionalFields; // see ADDITIONAL_FIELD_* defines
}

#define AT_ORIGIN 0
#define AT_ANGLES 1
#define AT_VELOCITY 2
#define AT_FLAGS 3

enum struct AdditionalTeleport {
  float atOrigin[3];
  float atAngles[3];
  float atVelocity[3];
  int atFlags;
}

enum struct FileHeader {
  int FH_binaryFormatVersion;
  int FH_recordEndTime;
  char FH_recordName[MAX_RECORD_NAME_LENGTH];
  int FH_tickCount;
  int FH_bookmarkCount;
  float FH_initialPosition[3];
  float FH_initialAngles[3];
  ArrayList FH_bookmarks;
  ArrayList FH_frames;
}

enum struct Bookmarks {
  int BKM_frame;
  int BKM_additionalTeleportTick;
  char BKM_name[MAX_BOOKMARK_NAME_LENGTH];
}

// Used to fire the OnPlayerMimicBookmark effciently during playback
enum struct BookmarkWhileMimicing {
  int BWM_frame; // The frame this bookmark was saved in
  int BWM_index; // The index into the FH_bookmarks array in the fileheader for the corresponding bookmark (to get the name)
}

// Real Bot
BMGameMode g_BotMimic_GameMode = BM_GameMode_Spect;

enum RouteType {
	DEFAULT_ROUTE = 0,
	FASTEST_ROUTE,
	SAFEST_ROUTE,
	RETREAT_ROUTE
}

#define VersusMode_MaxPositionDiff 3.0

Handle g_hVersusModeMoveTo;
Handle g_hVersusModeIsLineBlockedBySmoke;
Address g_pVersusModeTheBots;

bool g_VersusModeHandledByAi[MAXPLAYERS + 1] = {false, ...};
bool g_VersusModeAiStarted[MAXPLAYERS + 1] = {false, ...};
int g_VersusMode_Time[MAXPLAYERS + 1] = {-1, ...};
float g_VersusModeAiStartedTime[MAXPLAYERS + 1];
float g_VersusModeLastMimicPosition[MAXPLAYERS + 1][3];
bool g_VersusMode_MoveRight[MAXPLAYERS + 1];
bool g_VersusMode_Duck[MAXPLAYERS + 1];

#define VersusMode_ReactTimeMIN 60
int g_VersusMode_ReactTime = 120;
#define VersusMode_ReactTimeMAX 300

#define VersusMode_MoveDistanceMIN 60
int g_VersusMode_MoveDistance = 60;
#define VersusMode_MoveDistanceMAX 150

ConVar g_VersusMode_AttackTimeCvar;
ConVar g_VersusMode_SpotMultCvar;

// Where did he start recording. The bot is teleported to this position on replay.
float g_fInitialPosition[MAXPLAYERS + 1][3];
float g_fInitialAngles[MAXPLAYERS + 1][3];
// Array Cut Size
int g_hRecordingSizeLimit[MAXPLAYERS + 1];
// Array of frames
ArrayList g_hRecording[MAXPLAYERS + 1];
ArrayList g_hRecordingAdditionalTeleport[MAXPLAYERS + 1];
ArrayList g_hRecordingBookmarks[MAXPLAYERS + 1];
int g_iCurrentAdditionalTeleportIndex[MAXPLAYERS + 1];
// Is the recording currently paused?
bool g_bRecordingPaused[MAXPLAYERS + 1];
bool g_bSaveFullSnapshot[MAXPLAYERS + 1];
// How many calls to OnPlayerRunCmd were recorded?
int g_iRecordedTicks[MAXPLAYERS + 1];
// What's the last active weapon
int g_iRecordPreviousWeapon[MAXPLAYERS + 1];
// Count ticks till we save the position again
int g_iOriginSnapshotInterval[MAXPLAYERS + 1];
// The name of this recording
char g_sRecordName[MAXPLAYERS + 1][MAX_RECORD_NAME_LENGTH];
char g_sRecordPath[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char g_sRecordCategory[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char g_sRecordSubDir[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

StringMap g_hLoadedRecords;
StringMap g_hLoadedRecordsAdditionalTeleport;
StringMap g_hLoadedRecordsCategory;
ArrayList g_hSortedRecordList;
ArrayList g_hSortedCategoryList;

ArrayList g_hBotMimicsRecord[MAXPLAYERS + 1] = {null,...};
int g_iBotMimicTick[MAXPLAYERS + 1] = {0,...};
int g_iBotMimicRecordTickCount[MAXPLAYERS + 1] = {0,...};
int g_iBotActiveWeapon[MAXPLAYERS + 1] = {-1,...};
bool g_bBotSwitchedWeapon[MAXPLAYERS + 1];
bool g_bValidTeleportCall[MAXPLAYERS + 1];
bool g_bBotWaitingDelay[MAXPLAYERS + 1];
BookmarkWhileMimicing g_iBotMimicNextBookmarkTick[MAXPLAYERS + 1];

Handle g_hfwdOnStartRecording;
Handle g_hfwdOnRecordingPauseStateChanged;
Handle g_hfwdOnRecordingBookmarkSaved;
Handle g_hfwdOnStopRecording;
Handle g_hfwdOnRecordSaved;
Handle g_hfwdOnRecordDeleted;
Handle g_hfwdOnPlayerStartsMimicing;
Handle g_hfwdOnPlayerStopsMimicing;
Handle g_hfwdOnPlayerMimicLoops;
Handle g_hfwdOnPlayerMimicBookmark;

// DHooks
Handle g_hTeleport;

ConVar g_hCVOriginSnapshotInterval;

public Plugin myinfo = {
  name = "Bot Mimic",
  author = "Jannik \"Peace-Maker\" Hartung",
  description = "Bots mimic your movements!",
  version = PLUGIN_VERSION,
  url = "http://www.wcfan.de/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("botmimic");
  CreateNative("BotMimic_StartRecording", StartRecording);
  CreateNative("BotMimic_StopRecording", StopRecording);

  CreateNative("BotMimic_IsPlayerRecording", IsPlayerRecording);

  CreateNative("BotMimic_ResumeRecording", ResumeRecording);
  CreateNative("BotMimic_PauseRecording", PauseRecording);
  CreateNative("BotMimic_IsRecordingPaused", IsRecordingPaused);

  CreateNative("BotMimic_DeleteRecord", DeleteRecord);

  CreateNative("BotMimic_PlayRecordFromFile", PlayRecordFromFile);
  CreateNative("BotMimic_PlayRecordByName", PlayRecordByName);

  CreateNative("BotMimic_IsPlayerMimicing", IsPlayerMimicing);
  CreateNative("BotMimic_ResetPlayback", ResetPlayback);
  CreateNative("BotMimic_StopPlayerMimic", StopPlayerMimic);

  CreateNative("BotMimic_GetRecordPlayerMimics", GetRecordPlayerMimics);

  CreateNative("BotMimic_SaveBookmark", SaveBookmark);
  CreateNative("BotMimic_GoToBookmark", GoToBookmark);
  CreateNative("BotMimic_GetRecordBookmarks", GetRecordBookmarks);

  CreateNative("BotMimic_GetFileHeaders", GetFileHeaders);
  CreateNative("BotMimic_ChangeRecordName", ChangeRecordName);
  CreateNative("BotMimic_GetGameMode", GetGameMode);
  CreateNative("BotMimic_GetVersusModeReactionTime", GetVersusModeReactionTime);
  CreateNative("BotMimic_GetVersusModeMoveDistance", GetVersusModeMoveDistance);
  CreateNative("BotMimic_GetLoadedRecordList", GetLoadedRecordList);
  CreateNative("BotMimic_GetLoadedRecordCategoryList", GetLoadedRecordCategoryList);
  CreateNative("BotMimic_GetFileCategory", GetFileCategory);

  g_hfwdOnStartRecording = CreateGlobalForward("BotMimic_OnStartRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String);
  g_hfwdOnStopRecording = CreateGlobalForward("BotMimic_OnStopRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_CellByRef);
  g_hfwdOnRecordingPauseStateChanged = CreateGlobalForward("BotMimic_OnRecordingPauseStateChanged", ET_Ignore, Param_Cell, Param_Cell);

  g_hfwdOnRecordSaved = CreateGlobalForward("BotMimic_OnRecordSaved", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String, Param_String);
  g_hfwdOnRecordDeleted = CreateGlobalForward("BotMimic_OnRecordDeleted", ET_Ignore, Param_String, Param_String, Param_String);

  g_hfwdOnPlayerStartsMimicing = CreateGlobalForward("BotMimic_OnPlayerStartsMimicing", ET_Hook, Param_Cell, Param_String, Param_String, Param_String);
  g_hfwdOnPlayerMimicLoops = CreateGlobalForward("BotMimic_OnPlayerMimicLoops", ET_Hook, Param_Cell);
  g_hfwdOnPlayerStopsMimicing = CreateGlobalForward("BotMimic_OnPlayerStopsMimicing", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);

  g_hfwdOnPlayerMimicBookmark = CreateGlobalForward("BotMimic_OnPlayerMimicBookmark", ET_Ignore, Param_Cell, Param_String);
  g_hfwdOnRecordingBookmarkSaved = CreateGlobalForward("BotMimic_OnRecordingBookmarkSaved", ET_Ignore, Param_Cell, Param_String);
  return APLRes_Success;
}

public void OnPluginStart() {
  Handle hGameConfig = LoadGameConfigFile("botstuff.games");
  if (hGameConfig == INVALID_HANDLE)
    SetFailState("Failed to find botstuff.games game config.");

  if(!(g_pVersusModeTheBots = GameConfGetAddress(hGameConfig, "TheBots")))
		SetFailState("Failed to get TheBots address.");

  // CCSBot::MoveTo
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::MoveTo");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); // Move Position As Vector, Pointer
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // Move Type As Integer
  if ((g_hVersusModeMoveTo = EndPrepSDKCall()) == INVALID_HANDLE)
    SetFailState("Failed to create SDKCall for CCSBot::MoveTo signature!");

  // CBotManager::IsLineBlockedBySmoke
  StartPrepSDKCall(SDKCall_Raw);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBotManager::IsLineBlockedBySmoke");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
  PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
  if ((g_hVersusModeIsLineBlockedBySmoke = EndPrepSDKCall()) == INVALID_HANDLE)
    SetFailState("Failed to create SDKCall for CBotManager::IsLineBlockedBySmoke offset!");

  CreateConVar("sm_botmimic_version", PLUGIN_VERSION, "Bot Mimic version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

  // Save the position of clients every 10000 ticks
  // This is to avoid bots getting stuck in walls due to slightly lower jumps, if they don't touch the ground.
  g_hCVOriginSnapshotInterval = CreateConVar("sm_botmimic_snapshotinterval", "10000", "Save the position of clients every x ticks. This is to avoid bots getting stuck in walls during a long playback and lots of jumps.", _, true, 0.0);

  AutoExecConfig();

  // Maps path to .rec -> record enum
  g_hLoadedRecords = new StringMap();
  g_hLoadedRecordsAdditionalTeleport = new StringMap();

  // Maps path to .rec -> record category
  g_hLoadedRecordsCategory = new StringMap();

  // Save all paths to .rec files in the trie sorted by time
  g_hSortedRecordList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
  g_hSortedCategoryList = new ArrayList(ByteCountToCells(64));

  g_VersusMode_AttackTimeCvar = CreateConVar("sm_botmimic_attack_time", "30",
                              "How much ticks until bot stops shooting.", 0, true, 0.0, true, 100.0);
  g_VersusMode_SpotMultCvar = CreateConVar("sm_botmimic_spot_mult", "1.1",
                              "Only for testing purposes.", 0, true, 1.0, true, 2.0);

  HookEvent("player_spawn", Event_OnPlayerSpawn);
  HookEvent("player_death", Event_OnPlayerDeath);

  if (LibraryExists("dhooks")) {
    OnLibraryAdded("dhooks");
  }
}

public void ConVar_VersionChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
  convar.SetString(PLUGIN_VERSION);
}

/**
 * Public forwards
 */
public void OnLibraryAdded(const char[] name) {
  if (StrEqual(name, "dhooks") && g_hTeleport == null) {
    // Optionally setup a hook on CBaseEntity::Teleport to keep track of sudden place changes
    Handle hGameData = LoadGameConfigFile("sdktools.games");
    if (hGameData == null)
      return;
    int iOffset = GameConfGetOffset(hGameData, "Teleport");
    delete hGameData;
    if (iOffset == -1)
      return;
    
    g_hTeleport = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHooks_OnTeleport);
    if (g_hTeleport == null)
      return;
    DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
    DHookAddParam(g_hTeleport, HookParamType_ObjectPtr);
    DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
    if (GetEngineVersion() == Engine_CSGO)
      DHookAddParam(g_hTeleport, HookParamType_Bool);
    
    for(int i=1;i<=MaxClients;i++) {
      if (IsClientInGame(i))
        OnClientPutInServer(i);
    }
  }
}

public void OnLibraryRemoved(const char[] name) {
  if (StrEqual(name, "dhooks")) {
    g_hTeleport = null;
  }
}

public void OnMapStart() {
  // Clear old records for old map
  int iSize = g_hSortedRecordList.Length;
  char sPath[PLATFORM_MAX_PATH];
  FileHeader iFileHeader;
  Handle hAdditionalTeleport;
  for(int i=0;i<iSize;i++) {
    g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
    if (!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader))) {
      PrintToServer("[OnMapStart]Internal state error. %s was in the sorted list, but not in the actual storage.", sPath);
      continue;
    }
    if (iFileHeader.FH_frames != null)
      delete iFileHeader.FH_frames;
    if (iFileHeader.FH_bookmarks != null)
      delete iFileHeader.FH_bookmarks;
    if (g_hLoadedRecordsAdditionalTeleport.GetValue(sPath, hAdditionalTeleport))
      delete hAdditionalTeleport;
  }
  g_hLoadedRecords.Clear();
  g_hLoadedRecordsAdditionalTeleport.Clear();
  g_hLoadedRecordsCategory.Clear();
  g_hSortedRecordList.Clear();
  g_hSortedCategoryList.Clear();

  // Create our record directory
  BuildPath(Path_SM, sPath, sizeof(sPath), DEFAULT_RECORD_FOLDER);
  if (!DirExists(sPath))
    CreateDirectory(sPath, 511);

  // Check for categories
  DirectoryListing hDir = OpenDirectory(sPath);
  if (hDir == null)
    return;

  char sFile[64];
  FileType fileType;
  while(hDir.GetNext(sFile, sizeof(sFile), fileType)) {
    switch(fileType) {
      // Check all directories for records on this map
      case FileType_Directory: {
        // INFINITE RECURSION ANYONE?
        if (StrEqual(sFile, ".") || StrEqual(sFile, ".."))
          continue;
        
        BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", DEFAULT_RECORD_FOLDER, sFile);
        ParseRecordsInDirectory(sPath, sFile, false);
      }
    }
  }
  delete hDir;
}

public void OnClientPutInServer(int client) {
  if (g_hTeleport != null)
    DHookEntity(g_hTeleport, false, client);
}

public void OnClientDisconnect(int client) {
  g_VersusModeHandledByAi[client] = false;
  g_VersusModeAiStarted[client] = false;
  g_VersusMode_Time[client] = -1;
  // g_VersusModeAiStartedTime[client];
  g_VersusModeLastMimicPosition[client] = ZERO_VECTOR;
  g_VersusMode_MoveRight[client] = false;
  g_VersusMode_Duck[client] = false;
  g_fInitialPosition[client] = ZERO_VECTOR;
  g_fInitialAngles[client] = ZERO_VECTOR;
  g_hRecordingSizeLimit[client] = 0;
  if (g_hRecording[client] != null)
    BotMimic_StopRecording(client);
  delete g_hRecording[client];
  g_hRecording[client] = null;
  delete g_hRecordingAdditionalTeleport[client];
  g_hRecordingAdditionalTeleport[client] = null;
  delete g_hRecordingBookmarks[client];
  g_hRecordingBookmarks[client] = null;
  g_iCurrentAdditionalTeleportIndex[client] = 0;
  g_bRecordingPaused[client] = false;
  g_bSaveFullSnapshot[client] = false;
  g_iRecordedTicks[client] = 0;
  g_iRecordPreviousWeapon[client] = -1;
  g_iOriginSnapshotInterval[client] = 0;
  g_sRecordName[client][0] = 0;
  g_sRecordPath[client][0] = 0;
  g_sRecordCategory[client][0] = 0;
  g_sRecordSubDir[client][0] = 0;
  if (g_hBotMimicsRecord[client] != null)
    BotMimic_StopPlayerMimic(client);
  delete g_hBotMimicsRecord[client];
  g_hBotMimicsRecord[client] = null;
  g_iBotMimicTick[client] = 0;
  g_iBotMimicRecordTickCount[client] = 0;
  g_iBotActiveWeapon[client] = -1;
  g_bBotSwitchedWeapon[client] = false;
  g_bValidTeleportCall[client] = false;
  g_bBotWaitingDelay[client] = false;
  g_iBotMimicNextBookmarkTick[client].BWM_frame = 0;
  g_iBotMimicNextBookmarkTick[client].BWM_index = 0;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) {
  // Client is recording and recording is not paused.
  if (g_hRecording[client] == null || g_bRecordingPaused[client]) {
    return;
  }
  FrameInfo iFrame;
  iFrame.playerButtons = buttons;
  iFrame.playerImpulse = impulse;

  float vVel[3];
  Entity_GetAbsVelocity(client, vVel);
  iFrame.actualVelocity = vVel;
  iFrame.predictedVelocity = vel;
  iFrame.predictedAngles[0] = angles[0];
  iFrame.predictedAngles[1] = angles[1];
  iFrame.newWeapon = CSWeapon_NONE;
  iFrame.playerSubtype = subtype;
  iFrame.playerSeed = seed;

  // Save the origin, angles and velocity in this frame.
  if (g_bSaveFullSnapshot[client]) {
    AdditionalTeleport iAT;
    GetClientAbsOrigin(client, iAT.atOrigin);
    GetClientEyeAngles(client, iAT.atAngles);
    Entity_GetAbsVelocity(client, iAT.atVelocity);
    
    iAT.atFlags = ADDFIELD_TP_ORIGIN|ADDFIELD_TP_ANGLES|ADDFIELD_TP_VEL;
    g_hRecordingAdditionalTeleport[client].PushArray(iAT, sizeof(AdditionalTeleport));
    g_bSaveFullSnapshot[client] = false;
  } else {
    // Save the current position 
    int iInterval = g_hCVOriginSnapshotInterval.IntValue;
    if (iInterval > 0 && g_iOriginSnapshotInterval[client] > iInterval) {
      AdditionalTeleport iAT;
      GetClientAbsOrigin(client, iAT.atOrigin);
      iAT.atFlags |= ADDFIELD_TP_ORIGIN;
      g_hRecordingAdditionalTeleport[client].PushArray(iAT, sizeof(AdditionalTeleport));
      g_iOriginSnapshotInterval[client] = 0;
    }
  }

  g_iOriginSnapshotInterval[client]++;

  // Check for additional Teleports
  if (g_hRecordingAdditionalTeleport[client].Length > g_iCurrentAdditionalTeleportIndex[client]) {
    AdditionalTeleport iAT;
    g_hRecordingAdditionalTeleport[client].GetArray(g_iCurrentAdditionalTeleportIndex[client], iAT, sizeof(AdditionalTeleport));
    // Remember, we were teleported this frame!
    iFrame.additionalFields |= iAT.atFlags;
    g_iCurrentAdditionalTeleportIndex[client]++;
  }

  int iNewWeapon = -1;

  // Did he change his weapon?
  if (weapon) {
    iNewWeapon = weapon;
  } else {
    // Picked up a new one?
    int iWeapon = Client_GetActiveWeapon(client);
    // (FIX|ENHANCEMENT) SHOW CUSTOM KNIFES
    
    // He's holding a weapon and
    // we just started recording. Always save the first weapon!
    // or This is a new weapon, he didn't held before.
    if (iWeapon != -1 && (g_iRecordedTicks[client] == 0 || g_iRecordPreviousWeapon[client] != iWeapon)) {
      iNewWeapon = iWeapon;
    }
  }

  // (FIX|CLEANUP) WHY IS THIS NECCESSARY ?
  // ONLY SAVE THE g_iRecordPreviousWeapon[client]
  if (iNewWeapon != -1) {
    // Save it
    if (IsValidEntity(iNewWeapon) && IsValidEdict(iNewWeapon)) {
      g_iRecordPreviousWeapon[client] = iNewWeapon;
      
      char sClassName[64];
      GetEdictClassname(iNewWeapon, sClassName, sizeof(sClassName));
      ReplaceString(sClassName, sizeof(sClassName), "weapon_", "", false);
      
      char sWeaponAlias[64];
      CS_GetTranslatedWeaponAlias(sClassName, sWeaponAlias, sizeof(sWeaponAlias));
      CSWeaponID weaponId = CS_AliasToWeaponID(sWeaponAlias);
      
      iFrame.newWeapon = weaponId;
    }
  }
  g_hRecording[client].PushArray(iFrame, sizeof(FrameInfo));
  g_iRecordedTicks[client]++;

  // // FIX: store origin?
  // if (g_hRecordingSizeLimit[client] > 0) {
  //   if (g_hRecording[client].Length > g_hRecordingSizeLimit[client]) {
  //     // Option 1 -> FIX: store origin?
  //     // FrameInfo newFirstFrame;
  //     // g_hRecording[client].GetArray(0, newFirstFrame, sizeof(newFirstFrame));
  //     // g_fInitialAngles[client] = newFirstFrame.predictedAngles;
  //     // g_hRecording[client].Erase(0);
  //     // g_iRecordedTicks[client]--;
  //     // Option 2 -> Start Again
  //     GetClientEyeAngles(client, g_fInitialAngles[client]);
  //     GetClientAbsOrigin(client, g_fInitialPosition[client]);
  //     g_hRecording[client].Clear();
  //     g_iRecordedTicks[client] = 0;
  //   }
  // }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
  // Is Bot mimicing something ?
  if (g_hBotMimicsRecord[client] == null) {
    // what should he do when finished recording
    return Plugin_Continue;
  }
  // Is this a valid living bot?
  if (!IsPlayerAlive(client) || GetClientTeam(client) <= CS_TEAM_SPECTATOR) {
    return Plugin_Continue;
  }

  if (g_iBotMimicTick[client] >= g_iBotMimicRecordTickCount[client]) {
    // Reset Mimic
    g_iBotMimicTick[client] = 0;
    g_iCurrentAdditionalTeleportIndex[client] = 0;
    Action result;
    Call_StartForward(g_hfwdOnPlayerMimicLoops);
    Call_PushCell(client);
    Call_Finish(result);

    // Someone doesn't want this guy to loop this mimic.
    if (result >= Plugin_Handled) {
      BotMimic_StopPlayerMimic(client);
      return Plugin_Continue;
    }
  }

  // Get Info in This Frame
  FrameInfo iFrame;
  g_hBotMimicsRecord[client].GetArray(g_iBotMimicTick[client], iFrame, sizeof(FrameInfo));

  // The next call to Teleport is ok.
  g_bValidTeleportCall[client] = true;

  if (g_iBotMimicTick[client] == 0) {
    // This is the first tick. Teleport him to the initial position
    buttons = iFrame.playerButtons & ~IN_ATTACK;
    TeleportEntity(client, g_fInitialPosition[client], g_fInitialAngles[client], iFrame.actualVelocity);

    if (g_bBotWaitingDelay[client]) {
      return Plugin_Continue;
    }
    // Strip Weapons
    /* void CSGO_StripAllWeapons(int client) {
      int weapon;
      for (int i = 0; i < 3; i++)
      {
        if ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
        {
          if (GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") != client)
            SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);

          SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
          AcceptEntityInput(weapon, "Kill");
        }
      }
    } */
    // (FIX|REPLACE) CSGO_StripAllWeapons
    // Client_RemoveAllWeapons(client);
  } else {
    // All ticks except first one

    // Sees player -> saves current position as "POS1" -> turns into bot that crouches and strafes randomly
    // stops seeing player/kills player -> hold that position (random seconds)?
    // stopped holding position -> ai navmesh Move To "POS1"
    // Gets to "POS1" -> continues replay
    // Replay finishes -> Hold Zone(Custom CT AI), Defend Zone(Custom TT AI)

    int currentTarget = -1;
    if (g_BotMimic_GameMode == BM_GameMode_Versus) {
      float nearestDist = -1.0;
      bool HoldingWeapon = true;
      if (g_iBotActiveWeapon[client] != INVALID_ENT_REFERENCE) {
        char sAlias[64];
        Entity_GetClassName(g_iBotActiveWeapon[client], sAlias, sizeof(sAlias));
        if (StrContains(sAlias, "grenade") != -1
        || StrContains(sAlias, "flashbang") != -1
        || StrContains(sAlias, "knife") != -1
        || StrContains(sAlias, "decoy") != -1
        || StrContains(sAlias, "molotov") != -1) {
          HoldingWeapon = false;
        }
      }
      
      if (GetEntityFlags(client) & FL_ONGROUND && HoldingWeapon && GetFlashDuration(client) < 2.0) {
        for (int i = 0; i < MaxClients; i++) {
          int target = i;
          if (IsPlayer(target)) {
            if (!IsPlayerAlive(target)) {
              continue;
            }
            if (GetClientTeam(target) == GetClientTeam(client)) {
              continue;
            }
            float clientVec[3], targetVec[3];
            GetClientEyePosition(client, clientVec);
            GetClientEyePosition(target, targetVec);
            float Dist = GetVectorDistance(clientVec, targetVec);
            if (LineGoesThroughSmoke(clientVec, targetVec)) {
              continue;
            }
            if (Dist > nearestDist && nearestDist > -1.0) {
              continue;
            }
            if (!IsAbleToSee(client, target, 0.9)) {
              continue;
            }
            nearestDist = Dist;
            currentTarget = target;
            break;
          }
        }
      }

      if (currentTarget > 0) { // Target Found
        g_VersusModeHandledByAi[client] = false;
        g_VersusModeAiStarted[client] = false;
        float clientEyepos[3], viewTarget[3];
        GetClientEyePosition(client, clientEyepos);
        GetClientEyePosition(currentTarget, viewTarget);
        viewTarget[2] -= 5.0; // headshot or bodyshot(30.0) ?
        SubtractVectors(viewTarget, clientEyepos, viewTarget);
        GetVectorAngles(viewTarget, viewTarget);
        TeleportEntity(client, NULL_VECTOR, viewTarget, NULL_VECTOR);
        // Strafe movement perpendicular to player->bot vector
        // bot will stop and attack every g_VersusMode_ReactTime frames
        if (g_VersusMode_Time[client] >= g_VersusMode_ReactTime &&
            g_VersusMode_Time[client] <= (g_VersusMode_ReactTime+g_VersusMode_AttackTimeCvar.IntValue)) { // bot will attack for (2 + 1) frames
          vel[1] = 0.0;
          buttons |= IN_ATTACK;
          // buttons &= ~IN_SPEED;
          if (g_VersusMode_Time[client] == (g_VersusMode_ReactTime+g_VersusMode_AttackTimeCvar.IntValue)) {
            g_VersusMode_Duck[client] = !!GetRandomInt(0, 1);
            g_VersusMode_Time[client] = 0;
          }
          else g_VersusMode_Time[client]++;
        } else {
          buttons &= ~IN_ATTACK;
          buttons &= ~IN_DUCK;
          // buttons &= ~IN_SPEED;
          if (g_VersusMode_Time[client] == g_VersusMode_ReactTime - g_VersusMode_MoveDistance) { // the bot will be moving RKBOT_MOVEDISTANCE frames
            g_VersusMode_MoveRight[client] = !!GetRandomInt(0, 1);
            g_VersusMode_Duck[client] = !!GetRandomInt(0, 1);
            // g_RetakeBotWalk[client] = GetRandomInt(0, 1);
          } else {
            if (g_VersusMode_Time[client] > g_VersusMode_ReactTime - g_VersusMode_MoveDistance) { // while the bot is moving
              if (g_VersusMode_MoveRight[client]) vel[1] = 250.0;
              else vel[1] = -250.0;
              if (g_VersusMode_Duck[client]) buttons |= IN_DUCK;

              // if (g_RetakeBotWalk[client]) buttons |= IN_SPEED;
              if (g_VersusMode_Time[client] == g_VersusMode_ReactTime - g_VersusMode_MoveDistance + 5) { // just after the bot started moving to check if IS STUCK
                float fAbsVel[3];
                Entity_GetAbsVelocity(client, fAbsVel);
                if (GetVectorLength(fAbsVel) < 5.0) {
                  // Jump to Attack Time ?
                  // g_VersusMode_Time[client] = g_VersusMode_ReactTime;
                  g_VersusMode_MoveRight[client] = !g_VersusMode_MoveRight[client];
                }
              }
            } else {
              // unknown status (bot is standing?)
            }
          }
          g_VersusMode_Time[client]++;
        }
        return Plugin_Changed;
      } else { // No Target, but could have spotted a target before
        // If it even has mimiced before
        if (g_VersusMode_Time[client] > -1) {
          g_VersusMode_Time[client] = 0;
          // bot should continue mimicing, so first we check if its in the correct position, if not send him there
          float currentPosition[3];
          GetClientAbsOrigin(client, currentPosition);
          float vec1[3], vec2[3], zDiff;
          vec1 = currentPosition;
          vec1[2] = 0.0;
          vec2 = g_VersusModeLastMimicPosition[client];
          vec2[2] = 0.0;
          zDiff = FloatAbs(currentPosition[2]-g_VersusModeLastMimicPosition[client][2]);
          float distance = GetVectorDistance(vec1, vec2); //, true?
          // maybe change VersusMode_MaxPositionDiff because it doesnt matter if players cant see them
          if (distance <= VersusMode_MaxPositionDiff && zDiff <= 80) {
            // PrintHintTextToAll("validpos");
            // its on a valid position
            g_VersusModeHandledByAi[client] = false;
          } else {
            // PrintHintTextToAll("invalidpos");
            g_VersusModeHandledByAi[client] = true;
          }
        }
      }

      if (g_VersusModeHandledByAi[client]) {
        if (!g_VersusModeAiStarted[client]) {
          // Bot started to being handle by AI
          g_VersusModeAiStarted[client] = true;
          g_VersusModeAiStartedTime[client] = GetGameTime();
          BotMoveTo(client, g_VersusModeLastMimicPosition[client], FASTEST_ROUTE);
        }
        if (g_VersusModeAiStarted[client]) {
          // Bot is being handled by AI
          float currentPosition[3];
          GetClientAbsOrigin(client, currentPosition);
          float vec1[3], vec2[3], zDiff;
          vec1 = currentPosition;
          vec1[2] = 0.0;
          vec2 = g_VersusModeLastMimicPosition[client];
          vec2[2] = 0.0;
          zDiff = FloatAbs(currentPosition[2]-g_VersusModeLastMimicPosition[client][2]);
          float distance = GetVectorDistance(vec1, vec2); //, true?
          if (distance <= VersusMode_MaxPositionDiff && zDiff <= 90) { // Entity_GetAbsVelocity(client, currentVelocity); also?
            // Reached Expected Point
            g_VersusModeHandledByAi[client] = false;
            g_VersusModeAiStarted[client] = false;
          } else {
            // Bot should still be moving towards last mimic pos
            float currentTime = GetGameTime();
            if (currentTime-g_VersusModeAiStartedTime[client] > 0.8) {
              // Too much time, help him by teleporting him closer to its last position <- ?
              // PrintToConsoleAll("got stuck, pushed him closer to last position");
              //   g_VersusModeLastMimicPosition[client][1], g_VersusModeLastMimicPosition[client][2]);
              g_VersusModeAiStartedTime[client] = currentTime;
              //   currentPosition[1], currentPosition[2]);
              SubtractVectors(g_VersusModeLastMimicPosition[client], currentPosition, currentPosition);
              NormalizeVector(currentPosition, currentPosition);
              ScaleVector(currentPosition, 250.0); //1.5 is the velocity multiplier
              currentPosition[2] = 0.0;
              //   currentPosition[1], currentPosition[2]);
              // TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, currentPosition);
              BotMoveTo(client, g_VersusModeLastMimicPosition[client], FASTEST_ROUTE); //////
            }
            return Plugin_Changed;
          }
        }
      }
    }
    // PrintHintTextToAll("mimicmode");

    buttons = iFrame.playerButtons;
    impulse = iFrame.playerImpulse;
    vel = iFrame.predictedVelocity;
    angles = iFrame.predictedAngles;
    subtype = iFrame.playerSubtype;
    seed = iFrame.playerSeed;
    weapon = 0;

    // TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
    TeleportEntity(client, NULL_VECTOR, angles, iFrame.actualVelocity);
  }

  // Check New Weapon
  if (iFrame.newWeapon != CSWeapon_NONE) {
    // Try Change Weapon
    char sAlias[64];
    CS_WeaponIDToAlias(iFrame.newWeapon, sAlias, sizeof(sAlias));
    Format(sAlias, sizeof(sAlias), "weapon_%s", sAlias);
    // Bot has Weapon, Equip It
    int checkWeapon = Client_GetWeapon(client, sAlias);
    if (g_iBotMimicTick[client] > 0 && checkWeapon != INVALID_ENT_REFERENCE
    || g_iBotMimicTick[client] == 0 && checkWeapon != INVALID_ENT_REFERENCE) {
      weapon = checkWeapon;
      g_iBotActiveWeapon[client] = weapon;
      g_bBotSwitchedWeapon[client] = true;
    } else {
      // Bot doesnt have Weapon, Give It
      weapon = GivePlayerItem(client, sAlias);
      if (weapon != INVALID_ENT_REFERENCE) {
        g_iBotActiveWeapon[client] = weapon;
        // Switch to that new weapon on the next frame.
        g_bBotSwitchedWeapon[client] = true;

        // Grenades shouldn't be equipped.
        // Otherwise Bot Drops Them Immediatly and doesnt "throw them"
        // The throw is handled By csutils plugin
        if (StrContains(sAlias, "grenade") == -1 
        && StrContains(sAlias, "flashbang") == -1 
        && StrContains(sAlias, "decoy") == -1 
        && StrContains(sAlias, "molotov") == -1) {
          EquipPlayerWeapon(client, weapon);
        }
      }
    }
  } else if (g_bBotSwitchedWeapon[client]) {
    // Switch the weapon on the next frame after it was selected.
    g_bBotSwitchedWeapon[client] = false;
    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", g_iBotActiveWeapon[client]);
    Client_SetActiveWeapon(client, g_iBotActiveWeapon[client]);
  }

  GetClientAbsOrigin(client, g_VersusModeLastMimicPosition[client]);

  if (g_BotMimic_GameMode == BM_GameMode_Practice ||
    (g_BotMimic_GameMode == BM_GameMode_Versus && g_VersusMode_Time[client] >= 0)) {
    g_iBotMimicTick[client]++;
    return Plugin_Changed;
  }

  // TODO: (versusmode) Disable Teleport only When attacked
  // We're supposed to teleport stuff?
  if (iFrame.additionalFields & (ADDFIELD_TP_ORIGIN|ADDFIELD_TP_ANGLES|ADDFIELD_TP_VEL)) {
    AdditionalTeleport iAT;
    ArrayList hAdditionalTeleport;
    char sPath[PLATFORM_MAX_PATH];
    GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
    g_hLoadedRecordsAdditionalTeleport.GetValue(sPath, hAdditionalTeleport);
    if (g_iCurrentAdditionalTeleportIndex[client] > hAdditionalTeleport.Length) {
      PrintToServer("[BOTMIMIC-RUNCMD]ERROR: g_iCurrentAdditionalTeleportIndex[client] > hAdditionalTeleport.Length");
      BotMimic_StopPlayerMimic(client);
      return Plugin_Changed;
    }
    hAdditionalTeleport.GetArray(g_iCurrentAdditionalTeleportIndex[client], iAT, sizeof(iAT));

    // Only pass the arguments, if they were set..
    if (iFrame.additionalFields & (ADDFIELD_TP_ORIGIN)) {
      g_bValidTeleportCall[client] = true;
      TeleportEntity(client, iAT.atOrigin, NULL_VECTOR, NULL_VECTOR);
    }
    if (iFrame.additionalFields & (ADDFIELD_TP_ANGLES)) {
      g_bValidTeleportCall[client] = true;
      TeleportEntity(client, NULL_VECTOR, iAT.atAngles, NULL_VECTOR);
    }
    if (iFrame.additionalFields & (ADDFIELD_TP_VEL)) {
      g_bValidTeleportCall[client] = true;
      TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, iAT.atVelocity);
    }
    g_iCurrentAdditionalTeleportIndex[client]++;
  }

  // (FIX|CHECK) DONT NEED BOOKMARKS
  // See if there's a bookmark on this tick
  if (g_iBotMimicTick[client] == g_iBotMimicNextBookmarkTick[client].BWM_frame) {
    // Get the file header of the current playing record.
    char sPath[PLATFORM_MAX_PATH];
    GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
    FileHeader iFileHeader;
    g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));

    Bookmarks iBookmark;
    iFileHeader.FH_bookmarks.GetArray(g_iBotMimicNextBookmarkTick[client].BWM_index, iBookmark, sizeof(Bookmarks));
    
    // Cache the next tick in which we should fire the forward.
    UpdateNextBookmarkTick(client);
    
    // Call the forward
    Call_StartForward(g_hfwdOnPlayerMimicBookmark);
    Call_PushCell(client);
    Call_PushString(iBookmark.BKM_name);
    Call_Finish();
  }

  g_iBotMimicTick[client]++;

  return Plugin_Changed;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(client))
    return;

  // Restart moving on spawn!
  if (g_hBotMimicsRecord[client] != null) {
    g_iBotMimicTick[client] = 0;
    g_iCurrentAdditionalTeleportIndex[client] = 0;
  }
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(client))
    return;

  if (g_hRecording[client] != null) {
    // This one has been recording currently
    BotMimic_StopRecording(client, true);
  } else if (g_hBotMimicsRecord[client] != null) {
    // This bot has been mimicing
    if (g_BotMimic_GameMode == BM_GameMode_Practice) {
      // Respawn the bot after death
      g_iBotMimicTick[client] = 0;
      g_iCurrentAdditionalTeleportIndex[client] = 0;
      CreateTimer(0.1, Timer_DelayedRespawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    } else {
      BotMimic_StopPlayerMimic(client);
    }
  }
}

/* Timer Callbacks */
public Action Timer_DelayedRespawn(Handle timer, any userid) {
  int client = GetClientOfUserId(userid);
  if (!IsValidClient(client))
    return Plugin_Stop;

  if (g_hBotMimicsRecord[client] != null && IsClientInGame(client) && !IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) >= CS_TEAM_T)
    CS_RespawnPlayer(client);

  return Plugin_Stop;
}

// (FIX|CHECK) Does this help for double flash issue?
public Action Hook_WeaponCanSwitchTo(int client, int weapon) {
  if (g_hBotMimicsRecord[client] == null)
    return Plugin_Continue;

  if (g_iBotActiveWeapon[client] != weapon) {
    return Plugin_Stop;
  }
  return Plugin_Continue;
}

public MRESReturn DHooks_OnTeleport(int client, Handle hParams) {
  // This one is currently mimicing something.
  if (g_hBotMimicsRecord[client] != null) {
    // We didn't allow that teleporting. STOP THAT.
    if (!g_bValidTeleportCall[client])
      return MRES_Supercede;
    g_bValidTeleportCall[client] = false;
    return MRES_Ignored;
  }

  // Don't care if he's not recording.
  if (g_hRecording[client] == null)
    return MRES_Ignored;

  float origin[3], angles[3], velocity[3];
  bool bOriginNull = DHookIsNullParam(hParams, 1);
  bool bAnglesNull = DHookIsNullParam(hParams, 2);
  bool bVelocityNull = DHookIsNullParam(hParams, 3);

  if (!bOriginNull)
    DHookGetParamVector(hParams, 1, origin);

  if (!bAnglesNull) {
    for(int i=0;i<3;i++)
      angles[i] = DHookGetParamObjectPtrVar(hParams, 2, i*4, ObjectValueType_Float);
  }

  if (!bVelocityNull)
    DHookGetParamVector(hParams, 3, velocity);

  if (bOriginNull && bAnglesNull && bVelocityNull)
    return MRES_Ignored;

  AdditionalTeleport iAT;
  Array_Copy(origin, iAT.atOrigin, 3);
  Array_Copy(angles, iAT.atAngles, 3);
  Array_Copy(velocity, iAT.atVelocity, 3);

  // Remember, 
  if (!bOriginNull)
    iAT.atFlags |= ADDFIELD_TP_ORIGIN;
  if (!bAnglesNull)
    iAT.atFlags |= ADDFIELD_TP_ANGLES;
  if (!bVelocityNull)
    iAT.atFlags |= ADDFIELD_TP_VEL;

  g_hRecordingAdditionalTeleport[client].PushArray(iAT, sizeof(AdditionalTeleport));

  return MRES_Ignored;
}

/**
 * Natives
 */
public int StartRecording(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (g_hRecording[client] != null) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is already recording.");
    return 0;
  }

  if (g_hBotMimicsRecord[client] != null) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is currently mimicing another record.");
    return 0;
  }

  g_hRecording[client] = new ArrayList(sizeof(FrameInfo));
  g_hRecordingAdditionalTeleport[client] = new ArrayList(sizeof(AdditionalTeleport));
  g_hRecordingBookmarks[client] = new ArrayList(sizeof(Bookmarks));
  GetClientAbsOrigin(client, g_fInitialPosition[client]);
  GetClientEyeAngles(client, g_fInitialAngles[client]);
  g_iRecordedTicks[client] = 0;
  g_iOriginSnapshotInterval[client] = 0;

  GetNativeString(2, g_sRecordName[client], MAX_RECORD_NAME_LENGTH);
  GetNativeString(3, g_sRecordCategory[client], PLATFORM_MAX_PATH);
  GetNativeString(4, g_sRecordSubDir[client], PLATFORM_MAX_PATH);
  g_hRecordingSizeLimit[client] = GetNativeCell(5);

  if (g_sRecordCategory[client][0] == '\0')
    strcopy(g_sRecordCategory[client], sizeof(g_sRecordCategory[]), DEFAULT_CATEGORY);

  // Path:
  // data/botmimic/%CATEGORY%/map_name/%SUBDIR%/record.rec
  // subdir can be omitted, default category is "default"

  // All demos reside in the default path (data/botmimic)
  BuildPath(Path_SM, g_sRecordPath[client], PLATFORM_MAX_PATH, "%s%s", DEFAULT_RECORD_FOLDER, g_sRecordCategory[client]);

  // Remove trailing slashes
  if (g_sRecordPath[client][strlen(g_sRecordPath[client])-1] == '\\' ||
    g_sRecordPath[client][strlen(g_sRecordPath[client])-1] == '/')
    g_sRecordPath[client][strlen(g_sRecordPath[client])-1] = '\0';

  Action result;
  Call_StartForward(g_hfwdOnStartRecording);
  Call_PushCell(client);
  Call_PushString(g_sRecordName[client]);
  Call_PushString(g_sRecordCategory[client]);
  Call_PushString(g_sRecordSubDir[client]);
  Call_PushString(g_sRecordPath[client]);
  Call_Finish(result);

  if (result >= Plugin_Handled)
    BotMimic_StopRecording(client, false);
  return 0;
}

public int StopRecording(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  // Not recording..
  if (g_hRecording[client] == null) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
    return 0;
  }

  bool save = GetNativeCell(2);

  Action result;
  Call_StartForward(g_hfwdOnStopRecording);
  Call_PushCell(client);
  Call_PushString(g_sRecordName[client]);
  Call_PushString(g_sRecordCategory[client]);
  Call_PushString(g_sRecordSubDir[client]);
  Call_PushString(g_sRecordPath[client]);
  Call_PushCellRef(save);
  Call_Finish(result);

  // Don't stop recording?
  if (result >= Plugin_Handled)
    return 0;

  if (save) {
    int iEndTime = GetTime();
    
    char sMapName[64], sPath[PLATFORM_MAX_PATH];
    GetCurrentMap(sMapName, sizeof(sMapName));
    
    // Check if the default record folder exists?
    BuildPath(Path_SM, sPath, sizeof(sPath), DEFAULT_RECORD_FOLDER);
    // Remove trailing slashes
    if (sPath[strlen(sPath)-1] == '\\' || sPath[strlen(sPath)-1] == '/')
      sPath[strlen(sPath)-1] = '\0';
    
    if (!CheckCreateDirectory(sPath, 511))
      return 0;
    
    // Check if the category folder exists?
    BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", DEFAULT_RECORD_FOLDER, g_sRecordCategory[client]);
    if (!CheckCreateDirectory(sPath, 511))
      return 0;
    
    // Check, if there is a folder for this map already
    Format(sPath, sizeof(sPath), "%s/%s", g_sRecordPath[client], sMapName);
    if (!CheckCreateDirectory(sPath, 511))
      return 0;
    
    // Check if the subdirectory exists
    if (g_sRecordSubDir[client][0] != '\0') {
      Format(sPath, sizeof(sPath), "%s/%s", sPath, g_sRecordSubDir[client]);
      if (!CheckCreateDirectory(sPath, 511))
        return 0;
    }
    
    Format(sPath, sizeof(sPath), "%s/%d.rec", sPath, iEndTime);
    
    // Add to our loaded record list
    FileHeader iHeader;
    iHeader.FH_binaryFormatVersion = BINARY_FORMAT_VERSION;
    iHeader.FH_recordEndTime = iEndTime;
    iHeader.FH_tickCount = g_hRecording[client].Length;
    strcopy(iHeader.FH_recordName, MAX_RECORD_NAME_LENGTH, g_sRecordName[client]);
    Array_Copy(g_fInitialPosition[client], iHeader.FH_initialPosition, 3);
    Array_Copy(g_fInitialAngles[client], iHeader.FH_initialAngles, 3);
    iHeader.FH_frames = g_hRecording[client];
    
    if (g_hRecordingBookmarks[client].Length > 0) {
      iHeader.FH_bookmarkCount = g_hRecordingBookmarks[client].Length;
      iHeader.FH_bookmarks = g_hRecordingBookmarks[client];
    } else {
      delete g_hRecordingBookmarks[client];
    }
    
    if (g_hRecordingAdditionalTeleport[client].Length > 0) {
      g_hLoadedRecordsAdditionalTeleport.SetValue(sPath, g_hRecordingAdditionalTeleport[client]);
    } else {
      delete g_hRecordingAdditionalTeleport[client];
    }
    
    WriteRecordToDisk(sPath, iHeader);
    
    g_hLoadedRecords.SetArray(sPath, iHeader, sizeof(FileHeader));
    g_hLoadedRecordsCategory.SetString(sPath, g_sRecordCategory[client]);
    g_hSortedRecordList.PushString(sPath);
    if (g_hSortedCategoryList.FindString(g_sRecordCategory[client]) == -1)
      g_hSortedCategoryList.PushString(g_sRecordCategory[client]);
    SortRecordList();
    
    Call_StartForward(g_hfwdOnRecordSaved);
    Call_PushCell(client);
    Call_PushString(g_sRecordName[client]);
    Call_PushString(g_sRecordCategory[client]);
    Call_PushString(g_sRecordSubDir[client]);
    Call_PushString(sPath);
    Call_Finish();
  } else {
    delete g_hRecording[client];
    delete g_hRecordingAdditionalTeleport[client];
    delete g_hRecordingBookmarks[client];
  }

  g_hRecording[client] = null;
  g_hRecordingSizeLimit[client] = -1;
  g_hRecordingAdditionalTeleport[client] = null;
  g_hRecordingBookmarks[client] = null;
  g_iRecordedTicks[client] = 0;
  g_iRecordPreviousWeapon[client] = 0;
  g_sRecordName[client][0] = 0;
  g_sRecordPath[client][0] = 0;
  g_sRecordCategory[client][0] = 0;
  g_sRecordSubDir[client][0] = 0;
  g_iCurrentAdditionalTeleportIndex[client] = 0;
  g_iOriginSnapshotInterval[client] = 0;
  g_bRecordingPaused[client] = false;
  g_bSaveFullSnapshot[client] = false;
  return 0;
}

public int IsPlayerRecording(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return false;
  }

  return g_hRecording[client] != null;
}

public int ResumeRecording(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (g_hRecording[client] == null) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
    return 0;
  }

  if (!g_bRecordingPaused[client]) {
    ThrowNativeError(SP_ERROR_NATIVE, "Recording is not paused.");
    return 0;
  }

  // Save the new full position, angles and velocity.
  g_bSaveFullSnapshot[client] = true;

  g_bRecordingPaused[client] = false;

  Call_StartForward(g_hfwdOnRecordingPauseStateChanged);
  Call_PushCell(client);
  Call_PushCell(false);
  Call_Finish();
  return 0;
}

public int PauseRecording(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (g_hRecording[client] == null) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
    return 0;
  }

  if (g_bRecordingPaused[client]) {
    ThrowNativeError(SP_ERROR_NATIVE, "Recording is already paused.");
    return 0;
  }

  g_bRecordingPaused[client] = true;

  Call_StartForward(g_hfwdOnRecordingPauseStateChanged);
  Call_PushCell(client);
  Call_PushCell(true);
  Call_Finish();
  return 0;
}

public int IsRecordingPaused(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return false;
  }

  if (g_hRecording[client] == null) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
    return false;
  }

  return g_bRecordingPaused[client];
}

public int DeleteRecord(Handle plugin, int numParams) {
  int iLen;
  GetNativeStringLength(1, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(1, sPath, iLen+1);

  // Do we have this record loaded?
  FileHeader iFileHeader;
  if (!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader))) {
    if (!FileExists(sPath))
      return -1;
    
    // Try to load it to make sure it's a record file we're deleting here!
    BMError error = LoadRecordFromFile(sPath, DEFAULT_CATEGORY, iFileHeader, true, false);
    if (error == BM_FileNotFound || error == BM_BadFile)
      return -1;
  }

  int iCount;
  if (iFileHeader.FH_frames != null) {
    for(int i=1;i<=MaxClients;i++) {
      // Stop the bots from mimicing this one
      if (g_hBotMimicsRecord[i] == iFileHeader.FH_frames) {
        BotMimic_StopPlayerMimic(i);
        iCount++;
      }
    }
    
    // Discard the frames
    delete iFileHeader.FH_frames;
  }

  if (iFileHeader.FH_bookmarks != null) {
    delete iFileHeader.FH_bookmarks;
  }

  char sCategory[64];
  g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory));

  g_hLoadedRecords.Remove(sPath);
  g_hLoadedRecordsCategory.Remove(sPath);
  g_hSortedRecordList.Erase(g_hSortedRecordList.FindString(sPath));
  ArrayList hAT;
  if (g_hLoadedRecordsAdditionalTeleport.GetValue(sPath, hAT))
    delete hAT;
  g_hLoadedRecordsAdditionalTeleport.Remove(sPath);

  // Delete the file
  if (FileExists(sPath)) {
    DeleteFile(sPath);
  }

  Call_StartForward(g_hfwdOnRecordDeleted);
  Call_PushString(iFileHeader.FH_recordName);
  Call_PushString(sCategory);
  Call_PushString(sPath);
  Call_Finish();

  return iCount;
}

public int PlayRecordFromFile(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    return view_as<int>(BM_BadClient);
  }

  int iLen;
  GetNativeStringLength(2, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(2, sPath, iLen+1);
  float startDelay = GetNativeCell(3);

  if (!FileExists(sPath))
    return view_as<int>(BM_FileNotFound);

  return view_as<int>(PlayRecord(client, sPath, startDelay));
}

public int PlayRecordByName(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    return view_as<int>(BM_BadClient);
  }

  int iLen;
  GetNativeStringLength(2, iLen);
  char[] sName = new char[iLen+1];
  GetNativeString(2, sName, iLen+1);
  float startDelay = GetNativeCell(3);

  char sPath[PLATFORM_MAX_PATH];
  int iSize = g_hSortedRecordList.Length;
  FileHeader iFileHeader;
  int iRecentTimeStamp;
  char sRecentPath[PLATFORM_MAX_PATH];
  for(int i=0;i<iSize;i++) {
    g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
    g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));
    if (StrEqual(sName, iFileHeader.FH_recordName)) {
      if (iRecentTimeStamp == 0 || iRecentTimeStamp < iFileHeader.FH_recordEndTime)
      {
        iRecentTimeStamp = iFileHeader.FH_recordEndTime;
        strcopy(sRecentPath, sizeof(sRecentPath), sPath);
      }
    }
  }

  if (!iRecentTimeStamp || !FileExists(sRecentPath))
    return view_as<int>(BM_FileNotFound);

  return view_as<int>(PlayRecord(client, sRecentPath, startDelay));
}

public int IsPlayerMimicing(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return false;
  }

  return g_hBotMimicsRecord[client] != null;
}

public int ResetPlayback(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (!BotMimic_IsPlayerMimicing(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
    return 0;
  }

  g_iBotMimicTick[client] = 0;
  g_iCurrentAdditionalTeleportIndex[client] = 0;
  g_bValidTeleportCall[client] = false;
  g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
  g_iBotMimicNextBookmarkTick[client].BWM_index = -1;
  UpdateNextBookmarkTick(client);
  return 0;
}

public int StopPlayerMimic(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (!BotMimic_IsPlayerMimicing(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
    return 0;
  }
  char sPath[PLATFORM_MAX_PATH];
  GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));

  g_hBotMimicsRecord[client] = null;
  g_iBotMimicTick[client] = 0;
  g_iCurrentAdditionalTeleportIndex[client] = 0;
  g_iBotMimicRecordTickCount[client] = 0;
  g_bValidTeleportCall[client] = false;
  g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
  g_iBotMimicNextBookmarkTick[client].BWM_index = -1;

  // Versus Mode
  g_VersusModeHandledByAi[client] = false;
  g_VersusModeAiStarted[client] = false;
  g_VersusMode_Time[client] = -1;

  FileHeader iFileHeader;
  g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));

  SDKUnhook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);

  char sCategory[64];
  g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory));

  Call_StartForward(g_hfwdOnPlayerStopsMimicing);
  Call_PushCell(client);
  Call_PushString(iFileHeader.FH_recordName);
  Call_PushString(sCategory);
  Call_PushString(sPath);
  Call_Finish();
  return 0;
}

public int GetRecordPlayerMimics(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (!BotMimic_IsPlayerMimicing(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
    return 0;
  }

  int iLen = GetNativeCell(3);
  char[] sPath = new char[iLen];
  GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, iLen);
  SetNativeString(2, sPath, iLen);
  return 0;
}

public int SaveBookmark(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  // Not recording..
  if (g_hRecording[client] == null) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
    return 0;
  }

  char sBookmarkName[MAX_BOOKMARK_NAME_LENGTH];
  GetNativeString(2, sBookmarkName, sizeof(sBookmarkName));

  // First check if there already is a bookmark with this name
  Bookmarks iBookmark;
  int iSize = g_hRecordingBookmarks[client].Length;
  for(int i=0;i<iSize;i++) {
    g_hRecordingBookmarks[client].GetArray(i, iBookmark, sizeof(Bookmarks));
    if (StrEqual(iBookmark.BKM_name, sBookmarkName, false)) {
      ThrowNativeError(SP_ERROR_NATIVE, "There already is a bookmark named \"%s\".", sBookmarkName);
      return 0;
    }
  }

  // Save the current state so it can be restored when jumping to that frame.
  AdditionalTeleport iAT;
  float fBuffer[3];
  GetClientAbsOrigin(client, fBuffer);
  Array_Copy(fBuffer, iAT.atOrigin, 3);
  GetClientEyeAngles(client, fBuffer);
  Array_Copy(fBuffer, iAT.atAngles, 3);
  Entity_GetAbsVelocity(client, fBuffer);
  Array_Copy(fBuffer, iAT.atVelocity, 3);

  iAT.atFlags = ADDFIELD_TP_ORIGIN|ADDFIELD_TP_ANGLES|ADDFIELD_TP_VEL;

  FrameInfo iFrame;
  g_hRecording[client].GetArray(g_iRecordedTicks[client]-1, iFrame, sizeof(FrameInfo));
  // There already is some Teleport call saved this frame :(
  if ((iFrame.additionalFields & iAT.atFlags) != 0) {
    // Purge it and replace it with this one as we might have more information.
    g_hRecordingAdditionalTeleport[client].SetArray(g_iCurrentAdditionalTeleportIndex[client]-1, iAT, sizeof(AdditionalTeleport));
  } else {
    g_hRecordingAdditionalTeleport[client].PushArray(iAT, sizeof(AdditionalTeleport));
    g_iCurrentAdditionalTeleportIndex[client]++;
  }
  // Remember, we were teleported this frame!
  iFrame.additionalFields |= iAT.atFlags;

  int iWeapon = Client_GetActiveWeapon(client);
  if (iWeapon != INVALID_ENT_REFERENCE && iFrame.newWeapon == CSWeapon_NONE && IsValidEntity(iWeapon)) {
    char sClassName[64];
    GetEntityClassname(iWeapon, sClassName, sizeof(sClassName));
    ReplaceString(sClassName, sizeof(sClassName), "weapon_", "", false);
    
    char sWeaponAlias[64];
    CS_GetTranslatedWeaponAlias(sClassName, sWeaponAlias, sizeof(sWeaponAlias));
    CSWeaponID weaponId = CS_AliasToWeaponID(sWeaponAlias);
    iFrame.newWeapon = weaponId;
  }

  g_hRecording[client].SetArray(g_iRecordedTicks[client]-1, iFrame, sizeof(FrameInfo));

  // Save the bookmark
  iBookmark.BKM_frame = g_iRecordedTicks[client]-1;
  iBookmark.BKM_additionalTeleportTick = g_iCurrentAdditionalTeleportIndex[client]-1;
  strcopy(iBookmark.BKM_name, MAX_BOOKMARK_NAME_LENGTH, sBookmarkName);
  g_hRecordingBookmarks[client].PushArray(iBookmark, sizeof(Bookmarks));

  // Inform other plugins, that there's been a bookmark saved.
  Call_StartForward(g_hfwdOnRecordingBookmarkSaved);
  Call_PushCell(client);
  Call_PushString(sBookmarkName);
  Call_Finish();
  return 0;
}

public int GoToBookmark(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (!BotMimic_IsPlayerMimicing(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
    return 0;
  }

  char sBookmarkName[MAX_BOOKMARK_NAME_LENGTH];
  GetNativeString(2, sBookmarkName, sizeof(sBookmarkName));

  // Get the file header
  char sPath[PLATFORM_MAX_PATH];
  GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));

  FileHeader iFileHeader;
  g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));

  // Get the bookmark with this name
  Bookmarks iBookmark;
  int iBookmarkIndex;
  bool bBookmarkFound;
  for(;iBookmarkIndex<iFileHeader.FH_bookmarkCount;iBookmarkIndex++) {
    iFileHeader.FH_bookmarks.GetArray(iBookmarkIndex, iBookmark, sizeof(Bookmarks));
    if (StrEqual(iBookmark.BKM_name, sBookmarkName, false)) {
      bBookmarkFound = true;
      break;
    }
  }

  if (!bBookmarkFound) {
    ThrowNativeError(SP_ERROR_NATIVE, "There is no bookmark named \"%s\" in this record.", sBookmarkName);
    return 0;
  }

  g_iBotMimicTick[client] = iBookmark.BKM_frame;
  g_iCurrentAdditionalTeleportIndex[client] = iBookmark.BKM_additionalTeleportTick;

  // Remember that we're now at this bookmark.
  g_iBotMimicNextBookmarkTick[client].BWM_frame = iBookmark.BKM_frame;
  g_iBotMimicNextBookmarkTick[client].BWM_index = iBookmarkIndex;
  return 0;
}

public int GetRecordBookmarks(Handle plugin, int numParams) {
  int iLen;
  GetNativeStringLength(1, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(1, sPath, iLen+1);

  if (!FileExists(sPath)) {
    return view_as<int>(BM_FileNotFound);
  }

  FileHeader iFileHeader;
  if (!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader))) {
    char sCategory[64];
    if (!g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
      strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
    BMError error = LoadRecordFromFile(sPath, sCategory, iFileHeader, true, false);
    if (error != BM_NoError)
      return view_as<int>(error);
  }

  ArrayList hBookmarks = new ArrayList(ByteCountToCells(MAX_BOOKMARK_NAME_LENGTH));
  Bookmarks iBookmark;
  for(int i=0;i<iFileHeader.FH_bookmarkCount;i++) {
    iFileHeader.FH_bookmarks.GetArray(i, iBookmark, sizeof(Bookmarks));
    hBookmarks.PushString(iBookmark.BKM_name);
  }

  Handle hClone = CloneHandle(hBookmarks, plugin);
  delete hBookmarks;
  SetNativeCellRef(2, hClone);
  return view_as<int>(BM_NoError);
}

public int GetFileHeaders(Handle plugin, int numParams) {
  int iLen;
  GetNativeStringLength(1, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(1, sPath, iLen+1);

  if (!FileExists(sPath)) {
    return view_as<int>(BM_FileNotFound);
  }

  FileHeader iFileHeader;
  if (!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader))) {
    char sCategory[64];
    if (!g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
      strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
    BMError error = LoadRecordFromFile(sPath, sCategory, iFileHeader, true, false);
    if (error != BM_NoError)
      return view_as<int>(error);
  }

  BMFileHeader iExposedFileHeader;
  iExposedFileHeader.BMFH_binaryFormatVersion = iFileHeader.FH_binaryFormatVersion;
  iExposedFileHeader.BMFH_recordEndTime = iFileHeader.FH_recordEndTime;
  strcopy(iExposedFileHeader.BMFH_recordName, MAX_RECORD_NAME_LENGTH, iFileHeader.FH_recordName);
  iExposedFileHeader.BMFH_tickCount = iFileHeader.FH_tickCount;
  Array_Copy(iFileHeader.FH_initialPosition, iExposedFileHeader.BMFH_initialPosition, 3);
  Array_Copy(iFileHeader.FH_initialAngles, iExposedFileHeader.BMFH_initialAngles, 3);
  iExposedFileHeader.BMFH_bookmarkCount = iFileHeader.FH_bookmarkCount;

  
  int iSize = sizeof(BMFileHeader);
  if (numParams > 2)
    iSize = GetNativeCell(3);
  if (iSize > sizeof(BMFileHeader))
    iSize = sizeof(BMFileHeader);

  SetNativeArray(2, iExposedFileHeader, iSize);
  return view_as<int>(BM_NoError);
}

public int ChangeRecordName(Handle plugin, int numParams) {
  int iLen;
  GetNativeStringLength(1, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(1, sPath, iLen+1);

  if (!FileExists(sPath)) {
    return view_as<int>(BM_FileNotFound);
  }

  char sCategory[64];
  if (!g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
    strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);

  FileHeader iFileHeader;
  if (!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader))) {
    BMError error = LoadRecordFromFile(sPath, sCategory, iFileHeader, false, false);
    if (error != BM_NoError)
      return view_as<int>(error);
  }

  // Load the whole record first or we'd lose the frames!
  if (iFileHeader.FH_frames == null)
    LoadRecordFromFile(sPath, sCategory, iFileHeader, false, true);

  GetNativeStringLength(2, iLen);
  char[] sName = new char[iLen+1];
  GetNativeString(2, sName, iLen+1);

  strcopy(iFileHeader.FH_recordName, MAX_RECORD_NAME_LENGTH, sName);
  g_hLoadedRecords.SetArray(sPath, iFileHeader, sizeof(FileHeader));

  WriteRecordToDisk(sPath, iFileHeader);

  return view_as<int>(BM_NoError);
}

public int GetGameMode(Handle plugin, int numParams) {
  BMGameMode newGameMode = GetNativeCell(1);
  if (newGameMode != BM_GameMode_Invalid) {
    if (BM_GameMode_Spect <= newGameMode && newGameMode <= BM_GameMode_Practice) {
      g_BotMimic_GameMode = newGameMode;
    } else {
      ThrowNativeError(SP_ERROR_NATIVE, "Invalid gamemode given (param 1 = %d).", newGameMode);
    }
  }
  return view_as<int>(g_BotMimic_GameMode);
}

public int GetVersusModeReactionTime(Handle plugin, int numParams) {
  bool change = GetNativeCell(1);
  if (change) {
    g_VersusMode_ReactTime += 30;
    g_VersusMode_ReactTime = (g_VersusMode_ReactTime > VersusMode_ReactTimeMAX)
      ? VersusMode_ReactTimeMIN
      : g_VersusMode_ReactTime;
  }
  return g_VersusMode_ReactTime;
}

public int GetVersusModeMoveDistance(Handle plugin, int numParams) {
  bool change = GetNativeCell(1);
  if (change) {
    g_VersusMode_MoveDistance += 30;
    g_VersusMode_MoveDistance = (g_VersusMode_MoveDistance > VersusMode_MoveDistanceMAX)
      ? VersusMode_MoveDistanceMIN
      : g_VersusMode_MoveDistance;
  }
  return g_VersusMode_MoveDistance;
}

public int GetLoadedRecordList(Handle plugin, int numParams) {
  return view_as<int>(g_hSortedRecordList);
}

public int GetLoadedRecordCategoryList(Handle plugin, int numParams) {
  return view_as<int>(g_hSortedCategoryList);
}

public int GetFileCategory(Handle plugin, int numParams) {
  int iLen;
  GetNativeStringLength(1, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(1, sPath, iLen+1);

  iLen = GetNativeCell(3);
  char[] sCategory = new char[iLen];
  bool bFound = g_hLoadedRecordsCategory.GetString(sPath, sCategory, iLen);

  SetNativeString(2, sCategory, iLen);
  return view_as<int>(bFound);
}


/**
 * Helper functions
 */

void ParseRecordsInDirectory(const char[] sPath, const char[] sCategory, bool subdir) {
  char sMapFilePath[PLATFORM_MAX_PATH];
  // We already are in the map folder? Don't add it again!
  if (subdir) {
    strcopy(sMapFilePath, sizeof(sMapFilePath), sPath);
  }
  // We're in a category. add the mapname to load the correct records for the current map
  else
  {
    char sMapName[64];
    GetCurrentMap(sMapName, sizeof(sMapName));
    Format(sMapFilePath, sizeof(sMapFilePath), "%s/%s", sPath, sMapName);
  }

  DirectoryListing hDir = OpenDirectory(sMapFilePath);
  if (hDir == null)
    return;

  char sFile[64], sFilePath[PLATFORM_MAX_PATH];
  FileType fileType;
  FileHeader iFileHeader;
  while(hDir.GetNext(sFile, sizeof(sFile), fileType)) {
    switch(fileType) {
      // This is a record for this map.
      case FileType_File:
      {
        Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
        LoadRecordFromFile(sFilePath, sCategory, iFileHeader, true, false);
      }
      // There's a subdir containing more records.
      case FileType_Directory:
      {
        // INFINITE RECURSION ANYONE?
        if (StrEqual(sFile, ".") || StrEqual(sFile, ".."))
          continue;
        
        Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
        ParseRecordsInDirectory(sFilePath, sCategory, true);
      }
    }
    
  }
  delete hDir;
}

void WriteRecordToDisk(const char[] sPath, FileHeader iFileHeader) {
  File hFile = OpenFile(sPath, "wb");
  if (hFile == null) {
    PrintToServer("[WriteRecordToDisk]Can't open the record file for writing! (%s)", sPath);
    return;
  }

  hFile.WriteInt32(BM_MAGIC);
  hFile.WriteInt8(iFileHeader.FH_binaryFormatVersion);
  hFile.WriteInt32(iFileHeader.FH_recordEndTime);
  hFile.WriteInt8(strlen(iFileHeader.FH_recordName));
  hFile.WriteString(iFileHeader.FH_recordName, false);

  hFile.Write(view_as<int>(iFileHeader.FH_initialPosition), 3, 4);
  hFile.Write(view_as<int>(iFileHeader.FH_initialAngles), 2, 4);

  ArrayList hAdditionalTeleport;
  int iATIndex;
  g_hLoadedRecordsAdditionalTeleport.GetValue(sPath, hAdditionalTeleport);

  int iTickCount = iFileHeader.FH_tickCount;
  hFile.WriteInt32(iTickCount);

  int iBookmarkCount = iFileHeader.FH_bookmarkCount;
  hFile.WriteInt32(iBookmarkCount);

  // Write all bookmarks
  ArrayList hBookmarks = iFileHeader.FH_bookmarks;

  Bookmarks iBookmark;
  for(int i=0;i<iBookmarkCount;i++) {
    hBookmarks.GetArray(i, iBookmark, sizeof(Bookmarks));
    
    hFile.WriteInt32(iBookmark.BKM_frame);
    hFile.WriteInt32(iBookmark.BKM_additionalTeleportTick);
    hFile.WriteString(iBookmark.BKM_name, true);
  }

  FrameInfo iFrame;
  for(int i=0;i<iTickCount;i++) {
    iFileHeader.FH_frames.GetArray(i, iFrame, sizeof(FrameInfo));
    hFile.Write(iFrame, sizeof(FrameInfo), 4);
    
    // Handle the optional Teleport call
    if (hAdditionalTeleport != null && iFrame.additionalFields & (ADDFIELD_TP_ORIGIN|ADDFIELD_TP_ANGLES|ADDFIELD_TP_VEL)) {
      AdditionalTeleport iAT;
      hAdditionalTeleport.GetArray(iATIndex, iAT, sizeof(AdditionalTeleport));
      if (iFrame.additionalFields & ADDFIELD_TP_ORIGIN)
        hFile.Write(view_as<int>(iAT.atOrigin), 3, 4);
      if (iFrame.additionalFields & ADDFIELD_TP_ANGLES)
        hFile.Write(view_as<int>(iAT.atAngles), 3, 4);
      if (iFrame.additionalFields & ADDFIELD_TP_VEL)
        hFile.Write(view_as<int>(iAT.atVelocity), 3, 4);
      iATIndex++;
    }
  }

  delete hFile;
}

BMError LoadRecordFromFile(const char[] path, const char[] sCategory, FileHeader headerInfo, bool onlyHeader, bool forceReload) {
  if (!FileExists(path))
    return BM_FileNotFound;

  // Make sure the handle references are null in the input structure.
  headerInfo.FH_frames = null;
  headerInfo.FH_bookmarks = null;

  // Already loaded that file?
  bool bAlreadyLoaded = false;
  if (g_hLoadedRecords.GetArray(path, headerInfo, sizeof(FileHeader))) {
    // Header already loaded.
    if (onlyHeader && !forceReload)
      return BM_NoError;
    
    bAlreadyLoaded = true;
  }

  File hFile = OpenFile(path, "rb");
  if (hFile == null)
    return BM_FileNotFound;

  int iMagic;
  hFile.ReadInt32(iMagic);
  if (iMagic != BM_MAGIC) {
    delete hFile;
    return BM_BadFile;
  }

  int iBinaryFormatVersion;
  hFile.ReadUint8(iBinaryFormatVersion);
  headerInfo.FH_binaryFormatVersion = iBinaryFormatVersion;

  if (iBinaryFormatVersion > BINARY_FORMAT_VERSION) {
    delete hFile;
    return BM_NewerBinaryVersion;
  }

  int iRecordTime, iNameLength;
  hFile.ReadInt32(iRecordTime);
  hFile.ReadUint8(iNameLength);
  char[] sRecordName = new char[iNameLength+1];
  hFile.ReadString(sRecordName, iNameLength+1, iNameLength);
  sRecordName[iNameLength] = '\0';

  hFile.Read(view_as<int>(headerInfo.FH_initialPosition), 3, 4);
  hFile.Read(view_as<int>(headerInfo.FH_initialAngles), 2, 4);

  int iTickCount;
  hFile.ReadInt32(iTickCount);

  int iBookmarkCount;
  if (iBinaryFormatVersion >= 0x02) {
    hFile.ReadInt32(iBookmarkCount);
  }
  headerInfo.FH_bookmarkCount = iBookmarkCount;

  headerInfo.FH_recordEndTime = iRecordTime;
  strcopy(headerInfo.FH_recordName, MAX_RECORD_NAME_LENGTH, sRecordName);
  headerInfo.FH_tickCount = iTickCount;

  delete headerInfo.FH_frames;
  delete headerInfo.FH_bookmarks;
  ArrayList hAT;
  if (g_hLoadedRecordsAdditionalTeleport.GetValue(path, hAT)) {
    delete hAT;
    g_hLoadedRecordsAdditionalTeleport.Remove(path);
  }

  //PrintToServer("Record %s:", sRecordName);
  //PrintToServer("File %s:", path);
  //PrintToServer("EndTime: %d, BinaryVersion: 0x%x, ticks: %d, initialPosition: %f,%f,%f, initialAngles: %f,%f,%f", iRecordTime, iBinaryFormatVersion, iTickCount, headerInfo.FH_initialPosition[0], headerInfo.FH_initialPosition[1], headerInfo.FH_initialPosition[2], headerInfo.FH_initialAngles[0], headerInfo.FH_initialAngles[1], headerInfo.FH_initialAngles[2]);

  if (iBookmarkCount > 0) {
    // Read in all bookmarks
    ArrayList hBookmarks = new ArrayList(sizeof(Bookmarks));
    
    Bookmarks iBookmark;
    for(int i=0;i<iBookmarkCount;i++) {
      hFile.ReadInt32(iBookmark.BKM_frame);
      hFile.ReadInt32(iBookmark.BKM_additionalTeleportTick);
      hFile.ReadString(iBookmark.BKM_name, MAX_BOOKMARK_NAME_LENGTH);
      hBookmarks.PushArray(iBookmark, sizeof(Bookmarks));
    }
    
    headerInfo.FH_bookmarks = hBookmarks;
  }

  g_hLoadedRecords.SetArray(path, headerInfo, sizeof(FileHeader));
  g_hLoadedRecordsCategory.SetString(path, sCategory);

  if (!bAlreadyLoaded)
    g_hSortedRecordList.PushString(path);

  if (g_hSortedCategoryList.FindString(sCategory) == -1)
    g_hSortedCategoryList.PushString(sCategory);

  // Sort it by record end time
  SortRecordList();

  if (onlyHeader) {
    delete hFile;
    return BM_NoError;
  }

  // Read in all the saved frames
  ArrayList hRecordFrames = new ArrayList(sizeof(FrameInfo));
  ArrayList hAdditionalTeleport = new ArrayList(sizeof(AdditionalTeleport));

  FrameInfo iFrame;
  for(int i=0;i<iTickCount;i++) {
    hFile.Read(iFrame, sizeof(FrameInfo), 4);
    hRecordFrames.PushArray(iFrame, sizeof(FrameInfo));
    
    if (iFrame.additionalFields & (ADDFIELD_TP_ORIGIN|ADDFIELD_TP_ANGLES|ADDFIELD_TP_VEL)) {
      AdditionalTeleport iAT;
      if (iFrame.additionalFields & ADDFIELD_TP_ORIGIN)
        hFile.Read(view_as<int>(iAT.atOrigin), 3, 4);
      if (iFrame.additionalFields & ADDFIELD_TP_ANGLES)
        hFile.Read(view_as<int>(iAT.atAngles), 3, 4);
      if (iFrame.additionalFields & ADDFIELD_TP_VEL)
        hFile.Read(view_as<int>(iAT.atVelocity), 3, 4);
      iAT.atFlags = iFrame.additionalFields & (ADDFIELD_TP_ORIGIN|ADDFIELD_TP_ANGLES|ADDFIELD_TP_VEL);
      hAdditionalTeleport.PushArray(iAT, sizeof(AdditionalTeleport));
    }
  }

  headerInfo.FH_frames = hRecordFrames;

  g_hLoadedRecords.SetArray(path, headerInfo, sizeof(FileHeader));
  if (hAdditionalTeleport.Length > 0)
    g_hLoadedRecordsAdditionalTeleport.SetValue(path, hAdditionalTeleport);
  else
    delete hAdditionalTeleport;

  delete hFile;
  return BM_NoError;
}

void SortRecordList() {
  SortADTArrayCustom(g_hSortedRecordList, SortFuncADT_ByEndTime);
  SortADTArray(g_hSortedCategoryList, Sort_Descending, Sort_String);
}

public int SortFuncADT_ByEndTime(int index1, int index2, Handle arrayHndl, Handle hndl) {
  char path1[PLATFORM_MAX_PATH], path2[PLATFORM_MAX_PATH];
  ArrayList array = view_as<ArrayList>(arrayHndl);
  array.GetString(index1, path1, sizeof(path1));
  array.GetString(index2, path2, sizeof(path2));

  FileHeader header1, header2;
  g_hLoadedRecords.GetArray(path1, header1, sizeof(FileHeader));
  g_hLoadedRecords.GetArray(path2, header2, sizeof(FileHeader));

  return header1.FH_recordEndTime - header2.FH_recordEndTime;
}

BMError PlayRecord(int client, const char[] path, float startDelay) {
  // He's currently recording. Don't start to play some record on him at the same time.
  if (g_hRecording[client] != null) {
    return BM_BadClient;
  }

  FileHeader iFileHeader;
  g_hLoadedRecords.GetArray(path, iFileHeader, sizeof(FileHeader));

  // That record isn't fully loaded yet. Do that now.
  if (iFileHeader.FH_frames == null) {
    char sCategory[64];
    if (!g_hLoadedRecordsCategory.GetString(path, sCategory, sizeof(sCategory)))
      strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
    BMError error = LoadRecordFromFile(path, sCategory, iFileHeader, false, true);
    if (error != BM_NoError)
      return error;
  }

  g_hBotMimicsRecord[client] = iFileHeader.FH_frames;
  g_iBotMimicTick[client] = 0;
  g_iBotMimicRecordTickCount[client] = iFileHeader.FH_tickCount;
  g_iCurrentAdditionalTeleportIndex[client] = 0;
  g_iBotActiveWeapon[client] = INVALID_ENT_REFERENCE;
  g_bBotSwitchedWeapon[client] = false;
  if (startDelay > 0.0) {
    g_bBotWaitingDelay[client] = true;
    CreateTimer(startDelay, Timer_AllowPlayRecord, GetClientSerial(client));
  }

  // Cache at which tick we should fire the first OnPlayerMimicBookmark forward.
  g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
  g_iBotMimicNextBookmarkTick[client].BWM_index = -1;
  UpdateNextBookmarkTick(client);

  Array_Copy(iFileHeader.FH_initialPosition, g_fInitialPosition[client], 3);
  Array_Copy(iFileHeader.FH_initialAngles, g_fInitialAngles[client], 3);

  SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);

  // Respawn him to get him moving!
  if (IsClientInGame(client) && !IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T)
    CS_RespawnPlayer(client);

  char sCategory[64];
  g_hLoadedRecordsCategory.GetString(path, sCategory, sizeof(sCategory));

  Action result;
  Call_StartForward(g_hfwdOnPlayerStartsMimicing);
  Call_PushCell(client);
  Call_PushString(iFileHeader.FH_recordName);
  Call_PushString(sCategory);
  Call_PushString(path);
  Call_Finish(result);

  // Someone doesn't want this guy to play that record.
  if (result >= Plugin_Handled) {
    g_hBotMimicsRecord[client] = null;
    g_iBotMimicRecordTickCount[client] = 0;
    g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
    g_iBotMimicNextBookmarkTick[client].BWM_index = -1;
  }

  return BM_NoError;
}

Action Timer_AllowPlayRecord(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  g_bBotWaitingDelay[client] = false;
  return Plugin_Handled;
}

// Find the next frame in which a bookmark was saved, so the OnPlayerMimicBookmark forward can be called.
void UpdateNextBookmarkTick(int client) {
  // Not mimicing anything.
  if (g_hBotMimicsRecord[client] == null)
    return;

  char sPath[PLATFORM_MAX_PATH];
  GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
  FileHeader iFileHeader;
  g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));

  if (iFileHeader.FH_bookmarks == null)
    return;

  int iSize = iFileHeader.FH_bookmarks.Length;
  if (iSize == 0)
    return;

  int iCurrentIndex = g_iBotMimicNextBookmarkTick[client].BWM_index;
  // We just reached some bookmark regularly and want to proceed to wait for the next one sequentially.
  // If there is no further bookmarks, restart from the first one.
  iCurrentIndex++;
  if (iCurrentIndex >= iSize)
    iCurrentIndex = 0;

  Bookmarks iBookmark;
  iFileHeader.FH_bookmarks.GetArray(iCurrentIndex, iBookmark, sizeof(Bookmarks));
  g_iBotMimicNextBookmarkTick[client].BWM_frame = iBookmark.BKM_frame;
  g_iBotMimicNextBookmarkTick[client].BWM_index = iCurrentIndex;
}

stock bool CheckCreateDirectory(const char[] sPath, int mode) {
  if (!DirExists(sPath)) {
    CreateDirectory(sPath, mode);
    if (!DirExists(sPath)) {
      PrintToServer("[CheckCreateDirectory]Can't create a new directory. Please create one manually! (%s)", sPath);
      return false;
    }
  }
  return true;
}

stock void GetFileFromFrameHandle(ArrayList frames, char[] path, int maxlen) {
  int iSize = g_hSortedRecordList.Length;
  char sPath[PLATFORM_MAX_PATH];
  FileHeader iFileHeader;
  for(int i=0;i<iSize;i++) {
    g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
    g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));
    if (iFileHeader.FH_frames != frames)
      continue;
    
    strcopy(path, maxlen, sPath);
    break;
  }
}

//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////
//////////////////////////////// ACTIVE BOT MODE ////////////////////////////////

void BotMoveTo(int client, float fOrigin[3], RouteType routeType) {
	SDKCall(g_hVersusModeMoveTo, client, fOrigin, routeType);
}

bool LineGoesThroughSmoke(const float fFrom[3], const float fTo[3]) {
	return SDKCall(g_hVersusModeIsLineBlockedBySmoke, g_pVersusModeTheBots, fFrom, fTo);
} 

bool IsAbleToSee(int entity, int client, float spotValue) {
  // Skip all traces if the player isn't within the field of view.
  // - Temporarily disabled until eye angle prediction is added.
  // if (IsInFieldOfView(g_vEyePos[client], g_vEyeAngles[client], g_vAbsCentre[entity]))
  
  float vecOrigin[3], vecEyePos[3];
  GetClientAbsOrigin(entity, vecOrigin);
  GetClientEyePosition(client, vecEyePos);
  
  // Check if centre is visible.
  if (IsPointVisible(vecEyePos, vecOrigin)) {
      return true;
  }
  
  float vecEyePos_ent[3], vecEyeAng[3];
  GetClientEyeAngles(entity, vecEyeAng);
  GetClientEyePosition(entity, vecEyePos_ent);
  
  float mins[3], maxs[3];
  GetClientMins(client, mins);
  GetClientMaxs(client, maxs);
  // Check outer 4 corners of player.
  if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, spotValue)) {
      return true;
  }

  // Check if weapon tip is visible.
  // if (IsFwdVecVisible(vecEyePos, vecEyeAng, vecEyePos_ent)) {
  //     return true;
  // }

  // // Check outer 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 1.30)) {
  //     return true;
  // }
  // // Check inner 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 0.65)) {
  //     return true;
  // }

  return false;
}

bool IsRectangleVisible(const float start[3], const float end[3], const float mins[3], const float maxs[3], float scale=1.0) {
  float ZpozOffset = maxs[2];
  float ZnegOffset = mins[2];
  float WideOffset = ((maxs[0] - mins[0]) + (maxs[1] - mins[1])) / 4.0;

  // This rectangle is just a point!
  if (ZpozOffset == 0.0 && ZnegOffset == 0.0 && WideOffset == 0.0) {
      return IsPointVisible(start, end);
  }

  // Adjust to scale.
  ZpozOffset *= scale;
  ZnegOffset *= scale;
  WideOffset *= scale;
  
  // Prepare rotation matrix.
  float angles[3], fwd[3], right[3];

  SubtractVectors(start, end, fwd);
  NormalizeVector(fwd, fwd);

  GetVectorAngles(fwd, angles);
  GetAngleVectors(angles, fwd, right, NULL_VECTOR);

  float vRectangle[4][3], vTemp[3];

  // If the player is on the same level as us, we can optimize by only rotating on the z-axis.
  if (FloatAbs(fwd[2]) <= 0.7071) {
    ScaleVector(right, WideOffset);
    // Corner 1, 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vRectangle[0]);
    SubtractVectors(vTemp, right, vRectangle[1]);
    // Corner 3, 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vRectangle[2]);
    SubtractVectors(vTemp, right, vRectangle[3]);
  } else if (fwd[2] > 0.0) { // Player is below us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);
    
    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[3]);
  } else { // Player is above us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);

    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[3]);
  }

  // Run traces on all corners.
  for (int i = 0; i < 4; i++) {
    if (IsPointVisible(start, vRectangle[i])) {
        return true;
    }
  }

  return false;
}
