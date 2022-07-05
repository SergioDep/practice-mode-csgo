/* Define */
  #define MESSAGE_PREFIX "[\x05Comando\x01]"
  #define CFOption_BotsDifficultyMIN 0
  #define CFOption_BotsDifficultyMAX 5
  #define CFOption_MaxSimBotsMIN 1
  #define CFOption_MaxSimBotsMAX 5
  #define CFOption_BotReactTimeMIN 60
  #define CFOption_BotReactTimeMAX 300
  #define CFOption_BotStartDelayMIN 50
  #define CFOption_BotStartDelayMAX 400
  #define CFOption_BotStrafeChanceMIN 0
  #define CFOption_BotStrafeChanceMAX 3
  #define CFOption_BotWeaponsMIN 0
  #define CFOption_BotWeaponsMAX 5
  #define ALIAS_LENGTH 64
  #define COMMAND_LENGTH 64
  #define MAX_GRENADE_SAVES_PLAYER 512
  #define AUTH_LENGTH 64
  #define GRENADE_CODE_LENGTH 256
  #define MAX_DEMO_BOTS 5
  #define DemoOption_RoundRestart_MAX 8
  #define MAX_SIM_REPLAY_NADES 40
  #define PLAYER_HEIGHT 72.0
  #define CLASS_LENGTH 64
  #define ASSET_SMOKEMODEL "models/weapons/w_eq_smokegrenade_dropped.mdl"
  #define ASSET_MOLOTOVMODEL "models/weapons/w_eq_molotov_dropped.mdl"
  #define ASSET_INCENDIARYMODEL "models/weapons/w_eq_incendiarygrenade_dropped.mdl"
  #define ASSET_HEMODEL "models/weapons/w_eq_fraggrenade_dropped.mdl"
  #define ASSET_FLASHMODEL "models/weapons/w_eq_flashbang_dropped.mdl"
  #define GRENADEMODEL_HEIGHT 32.0
  #define GRENADEMODEL_SCALE 4.0
  #define MAX_NADE_GROUP_DISTANCE 150.0
  #define MAX_NADE_INTERACT_DISTANCE 80.0
  #define BUTTON_PLAYER_NOCLIP_DIST 84.0
  #define SMOKE_EMIT_SOUND "weapons/smokegrenade/smoke_emit.wav"
  #define GRENADE_COLOR_SMOKE {55, 235, 19, 255} // "55 235 19"
  #define GRENADE_COLOR_FLASH {87, 234, 247, 255} // "87 234 247"
  #define GRENADE_COLOR_MOLOTOV {255, 161, 46, 255} // "255 161 46"
  #define GRENADE_COLOR_HE {250, 7, 7, 255} // "250 7 7"
  #define GRENADE_COLOR_DEFAULT {180, 180, 180, 255} // "180 180 180"
  #define MAX_GRENADES_IN_GROUP 15 //its actually 14, 0 is the ent, 1 is grenadeId of ent; 2,3,4,...14 are the grenades inside this
  #define interval_per_tick 0.0078125 //0.05 0.01801 0.0078125
  #define GenerateViewPointDelay 1
  #define GRENADE_FAILSAFE_MAX_BOUNCES 20
  #define STOP_EPSILON 0.1
  #define AFK_WARNING_DELAY 10.0
  // #define GRENADE_DETONATE_FLASH_TIME 1.658
  // #define GRENADE_DETONATE_MOLOTOV_TIME 1.96
//

/* Ints */
  int g_Crossfire_Countdown = -1;
  int g_Crossfire_DeathPlayersCount;
  int g_Crossfire_BotsDifficulty = 3;
  int g_Crossfire_MaxSimBots = 2;
  int g_Crossfire_BotReactTime = 180;
  int g_Crossfire_BotStartDelay = 100;
  int g_Crossfire_BotStrafeChance = 2;
  int g_Crossfire_BotWeapons = 4;
  int g_Crossfire_Players_Points[MAXPLAYERS + 1];
  int g_Crossfire_Players_Room[MAXPLAYERS + 1] = {-1, ...};
  int g_Crossfire_StartTime[MAXPLAYERS + 1] = {CFOption_BotStartDelayMIN, ...};
  int g_Crossfire_Time[MAXPLAYERS + 1];
  int g_Crossfire_StrafeHoldTime[MAXPLAYERS + 1];
  int g_Crossfire_SeenTime[MAXPLAYERS + 1];
  int g_Crossfire_SeenTotalTime[MAXPLAYERS + 1];
  int g_Demo_CurrentNade = -1;
  int g_Demo_FullRecordingClient = -1;
  int g_Demo_RoundRestart[MAXPLAYERS + 1];
  int g_Demo_CurrentEditingRole[MAXPLAYERS + 1] = {-1, ...};
  int g_Demo_SelectedRoleId[MAXPLAYERS + 1] = {-1, ...}; //g_CurrentEditingRole[client] = -1;
  int g_Demo_Match_CurrentRoundIndex = 0;
  int g_Demo_Match_CurrentSpeed = 100;
  int g_Demo_Match_SelectedId = -1;

  int g_Nade_HistoryIndex[MAXPLAYERS + 1] = {-1, ...};
  int g_Nade_PulledPinButtons[MAXPLAYERS + 1];
  int g_Nade_LastEntity[MAXPLAYERS + 1];
  int g_Nade_NextId;
  int g_Nade_CurrentGroupControl[MAXPLAYERS + 1] = {-1, ...};
  int g_Nade_CurrentControl[MAXPLAYERS + 1] = {-1, ...};
  GrenadeType g_Nade_LastType[MAXPLAYERS + 1];
  E_Nade_MenuType g_Nade_LastMenuType[MAXPLAYERS + 1];
  GrenadeType g_Nade_LastMenuTypeFilter[MAXPLAYERS + 1];
  E_Nade_PredictMode g_Nade_Pred_LastMode[MAXPLAYERS + 1] = {Grenade_PredictMode_None, ...};
  GrenadeType g_Nade_Pred_LastEquiped[MAXPLAYERS + 1];
  int g_Nade_Pred_ObservingGrenade[MAXPLAYERS + 1] = {-2, ...};
  int g_Nade_Pred_FinalDestEnt[MAXPLAYERS + 1] = {-1, ...};
  int g_Nade_Pred_GenerateViewPointDelay[MAXPLAYERS + 1] = {GenerateViewPointDelay, ...};
  int g_Nade_Pred_CurrentLineup[MAXPLAYERS + 1] = {-1, ...};
  int g_Nade_DemoRecordingStatus[MAXPLAYERS + 1];// 0 = not recording/canceled, 1 = recording, 2 = not recording/saved
  int g_Nade_CurrentSavedId[MAXPLAYERS + 1] = {-1, ...};
  int g_Nade_ClientSpecBot[MAXPLAYERS + 1] = {-1, ...};
  int g_Nade_LastSpecPlayerTeam[MAXPLAYERS + 1] = {-1, ...};

  int g_Manico_BotTargetSpotOffset;
  int g_Manico_BotNearbyEnemiesOffset;
  int g_Manico_FireWeaponOffset;
  int g_Manico_EnemyVisibleOffset;
  int g_Manico_BotProfileOffset;
  int g_Manico_BotEnemyOffset;
  int g_Manico_BotMoraleOffset;
  int g_Manico_UncrouchChance[MAXPLAYERS + 1];
  int g_Manico_Target[MAXPLAYERS + 1];
  CNavArea g_Manico_CurrArea[MAXPLAYERS + 1];
  Address g_Manico_TheBots;

  int g_PracticeSetupClient = -2;
  int g_PredictTrail = -1;
  int g_BeamSprite = -1;
  // int g_currentReplayGrenade = -1;
  const int kMaxBackupsPerMap = 50;
  int g_SpawnsLengthCt;
  int g_Bots_PlayerModels[MAXPLAYERS + 1] = {-1, ...};
  int g_Bots_PlayerModelsIndex[MAXPLAYERS + 1] = {-1, ...};
  int g_Is_DemoBot[MAXPLAYERS + 1]; //0 = not a demo bot, else role number
  int g_Bots_CurrentControl[MAXPLAYERS + 1] = {-1, ...};
  int g_Bots_MindControlOwner[MAXPLAYERS + 1] = {-1, ...};
  int g_Bots_NameNumber[MAXPLAYERS + 1];
  int g_LastNoclipCommand[MAXPLAYERS + 1];

  int g_Retake_BombTicking;
  int g_Retake_DeathPlayersCount;
  E_Retake_Diff g_Retake_Difficulty = Retake_Diff_Medium;
  int g_Retake_BotTime[MAXPLAYERS + 1];
  int g_Retake_BotDirection[MAXPLAYERS + 1];
  int g_Retake_BotDuck[MAXPLAYERS + 1];
  // int g_RetakeBotWalk[MAXPLAYERS + 1];
  int g_Retake_PlayersPoints[MAXPLAYERS + 1];
  E_TimerType g_TimerType[MAXPLAYERS + 1];
//

/* Char */
  char g_Bots_OriginalName[MAXPLAYERS + 1][MAX_NAME_LENGTH]; // Used for kicking them, otherwise they rejoin
  char g_Bots_SpawnWeapon[MAXPLAYERS + 1][64];
  char g_Crossfire_ActiveId[OPTION_ID_LENGTH];
  char g_Crossfire_PlayerWeapon[MAXPLAYERS + 1][128];
  char g_Crossfire_SelectedId[OPTION_ID_LENGTH];
  char g_Demo_SelectedId[MAXPLAYERS + 1][OPTION_ID_LENGTH];
  char g_Demo_Match_SelectedPlayerPath[PLATFORM_MAX_PATH];
  // char g_Demo_Matches_[MAX_DEMOS]
  char g_Nade_LocationsFile[PLATFORM_MAX_PATH];
  char g_Demo_Matches_File[PLATFORM_MAX_PATH];
  char g_Retake_PlayId[OPTION_ID_LENGTH];
  char g_Retake_SelectedId[OPTION_ID_LENGTH];
  char g_sLogs[PLATFORM_MAX_PATH + 1];

  char nadelist[] = "weapon_hegrenade weapon_smokegrenade weapon_flashbang weapon_incgrenade weapon_tagrenade weapon_molotov weapon_decoy";

  char _mapNames[][] = {"Dust2", "Inferno", "Mirage",
                                "Nuke", "Overpass", "Train", "Vertigo", "Cache", "Cobble"};
  char _mapCodes[][] = {"de_dust2", "de_inferno", "de_mirage",
                                "de_nuke", "de_overpass", "de_train", "de_vertigo", "de_cache", "de_cbble"};
  char g_szBoneNames[][] =  {
    "neck_0", 
    "pelvis", 
    "spine_0", 
    "spine_1", 
    "spine_2", 
    "spine_3", 
    "clavicle_l",
    "clavicle_r",
    "arm_upper_L", 
    "arm_lower_L", 
    "hand_L", 
    "arm_upper_R", 
    "arm_lower_R", 
    "hand_R", 
    "leg_upper_L",  
    "leg_lower_L", 
    "ankle_L",
    "leg_upper_R", 
    "leg_lower_R",
    "ankle_R"
  };
//

/* Float */
  // float g_ClientReplayGrenadeThrowTime[MAX_SIM_REPLAY_NADES];
  // float g_TiempoRecorrido[MAX_SIM_REPLAY_NADES] = {0.0, ...};
  // float g_ReplayGrenadeLastPausedTime = -1.0;
  // float g_ReplayGrenadeLastResumedTime[MAX_SIM_REPLAY_NADES] = {-1.0, ...};
  // float g_ReplayGrenadeLastLastResumedTime[MAX_SIM_REPLAY_NADES] ={ -1.0, ...};
  float g_AFK_LastCheckTime[MAXPLAYERS + 1] = {0.0, ...};
  float g_AFK_LastMovementTime[MAXPLAYERS + 1] = {0.0, ...};
  float g_AFK_LastEyeAngle[MAXPLAYERS + 1][3];
  float g_AFK_LastPosition[MAXPLAYERS + 1][3];
  float g_Bots_SpawnOrigin[MAXPLAYERS + 1][3];
  float g_Bots_SpawnAngles[MAXPLAYERS + 1][3];
  float g_CrossFire_SpawnOrigin[MAXPLAYERS + 1][3];
  float g_CrossFire_MaxOrigin[MAXPLAYERS + 1][3];
  float g_Demo_LastSpecPos[MAXPLAYERS + 1][3];
  float g_Demo_GrenadeThrowTime[MAX_SIM_REPLAY_NADES];
  float g_Demo_LastSpecAng[MAXPLAYERS + 1][3];
  float g_Demo_CurrentRecordingStartTime[MAXPLAYERS + 1];
  float g_Nade_LastFlashDetonateTime[MAXPLAYERS + 1];
  float g_Nade_LastPinPulledPos[MAXPLAYERS + 1][3];
  float g_Nade_LastPinPulledAng[MAXPLAYERS + 1][3];
  float g_Nade_LastOrigin[MAXPLAYERS + 1][3];
  float g_Nade_LastVelocity[MAXPLAYERS + 1][3];
  float g_Nade_LastDetonationOrigin[MAXPLAYERS + 1][3];
  float g_Nade_Pred_LastViewPos[MAXPLAYERS + 1][3];
  float g_Nade_Pred_LastViewAng[MAXPLAYERS + 1][3];
  float g_Nade_Pred_LastAng[MAXPLAYERS + 1][3];
  float g_Nade_Pred_Origin[MAXPLAYERS + 1][3];
  float g_Manico_TargetPos[MAXPLAYERS + 1][3];
  float g_Manico_NadeTarget[MAXPLAYERS + 1][3];
  float g_Manico_LookAngleMaxAccel[MAXPLAYERS + 1];
  float g_Manico_ReactionTime[MAXPLAYERS + 1];
  float g_TestingFlash_Origins[MAXPLAYERS + 1][3];
  float g_TestingFlash_Angles[MAXPLAYERS + 1][3];
  float g_Timer_Duration[MAXPLAYERS + 1];
  float g_Timer_LastCommand[MAXPLAYERS + 1];

//

/* Bool */
  bool g_AFK_autoCheck;
  bool g_AFK_Warned[MAXPLAYERS + 1];

  bool g_Crossfire_UpdatedKv = false;
  bool g_Crossfire_PlayersReady = false;
  bool g_Crossfire_EndlessMode = false;
  bool g_Crossfire_BotsAttack = true;
  bool g_Crossfire_BotsFlash = false;
  bool g_Crossfire_WaitForSave[MAXPLAYERS + 1];
  bool g_Crossfire_AllowedToAttack[MAXPLAYERS + 1];
  bool g_Crossfire_Ducking[MAXPLAYERS + 1];
  bool g_Crossfire_Strafe[MAXPLAYERS + 1];
  bool g_Crossfire_Seen[MAXPLAYERS + 1];
  bool g_Crossfire_Moving[MAXPLAYERS + 1];

  bool g_Demo_UpdatedKv = false;
  bool g_Demo_FullRecording = false;
  bool g_Demo_WaitForSave[MAXPLAYERS + 1];
  bool g_Demo_WaitForRoleSave[MAXPLAYERS + 1];
  bool g_Demo_WaitForDemoSave[MAXPLAYERS + 1];
  bool g_Demo_BotStopped[MAXPLAYERS + 1];
  bool g_Demo_PlayRoundTimer[MAXPLAYERS + 1];
  // bool g_Demo_Match_Started;

  bool g_Manico_BombPlanted;
  bool g_Manico_EveryoneDead;
  bool g_Manico_Zoomed[MAXPLAYERS + 1];
  bool g_Manico_DontSwitch[MAXPLAYERS + 1];

  bool g_Nade_UpdatedKv = false;
  bool g_Nade_LoadDefault = false;
  bool g_Nade_WaitForSave[MAXPLAYERS + 1];
  bool g_Nade_NewDemoSaved[MAXPLAYERS + 1];
  bool g_Nade_PulledPin[MAXPLAYERS + 1];
  bool g_Nade_Pred_Debuging[MAXPLAYERS + 1];
  bool g_Nade_Pred_LastCrouch[MAXPLAYERS + 1];
  bool g_Nade_Pred_Allowed[MAXPLAYERS + 1];
  bool g_Nade_Pred_InUseButtons[MAXPLAYERS + 1];
  bool g_Nade_Pred_InReloadButtons[MAXPLAYERS + 1];
  bool g_Nade_Pred_ViewEndPoint[MAXPLAYERS + 1];

  bool g_Retake_UpdatedKv = false;
  bool g_Retake_WaitForSave[MAXPLAYERS + 1];

  bool g_InPracticeMode = false;
  bool g_InDryMode = false;
  bool g_InRetakeMode = false;
  bool g_InCrossfireMode = false;
  bool g_InBotDemoMode = false;
  bool g_BotMimicLoaded = false;
  bool g_CleaningDroppedWeapons = false;
  bool g_WaitForServerPassword = false;
  bool g_TestingFlash[MAXPLAYERS + 1];
  bool g_NoFlash_Active[MAXPLAYERS + 1];
  bool g_Is_PMBot[MAXPLAYERS + 1];
  bool g_Is_RetakeBot[MAXPLAYERS + 1];
  bool g_Is_CrossfireBot[MAXPLAYERS + 1];
  bool g_Is_NadeBot[MAXPLAYERS + 1];
  bool g_Is_DemoVersusBot[MAXPLAYERS + 1];
  bool g_Is_Demo_Match_Bot[MAXPLAYERS + 1];
  bool g_Bots_Duck[MAXPLAYERS + 1];
  bool g_Bots_Jump[MAXPLAYERS + 1];

  bool g_Timer_RunningCommand[MAXPLAYERS + 1];
  bool g_Timer_RunningLiveCommand[MAXPLAYERS + 1];

  bool g_Misc_InUseButtons[MAXPLAYERS + 1];

//

/* Handle */
  Handle HudSync;
  // Handle ExplodeNadeTimer[MAX_SIM_REPLAY_NADES] = {INVALID_HANDLE, ...};
  Handle g_OnGrenadeSaved;
  Handle g_OnPracticeModeDisabled;
  Handle g_OnPracticeModeEnabled;
  Handle g_Crossfire_CountdownHandle;
  Handle g_Manico_BotMoveTo;
  Handle g_Manico_LookupBone;
  Handle g_Manico_GetBonePosition;
  Handle g_Manico_BotIsVisible;
  Handle g_Manico_BotIsHiding;
  Handle g_Manico_BotEquipBestWeapon;
  Handle g_Manico_SwitchWeaponCall;
  Handle g_Manico_IsLineBlockedBySmoke;
  Handle g_Manico_BotBendLineOfSight;
  Handle g_AFK_AdminImmune;
  Handle g_AFK_TimerDelay;
  Handle g_AFK_MaxTime;
  Handle hSvPasswordChangeCallback;
  Database g_Nade_Pred_Db;
  Handle g_Nade_OnGrenadeThrownForward = INVALID_HANDLE;
  Handle g_Nade_OnGrenadeExplodeForward = INVALID_HANDLE;
  Handle g_Nade_OnManagedGrenadeExplodeForward = INVALID_HANDLE;
//

/* ArrayList */
  ArrayList g_Breakable_Doors;
  ArrayList g_Breakable_FuncBks;
  ArrayList g_Breakable_Dynamics;
  ArrayList g_Crossfire_HoloEnts;
  ArrayList g_Crossfire_Players;
  ArrayList g_Crossfire_Bots;
  ArrayList g_Crossfire_Arenas;
  ArrayList g_Demo_Bots;
  ArrayList g_Demo_Match_Bots;
  ArrayList g_Demo_Matches;
  ArrayList g_Nade_HoloEnts;
  ArrayList g_Nade_HoloEnabledAuth;
  ArrayList g_Nade_HistoryPositions[MAXPLAYERS + 1];
  ArrayList g_Nade_HistoryAngles[MAXPLAYERS + 1];
  ArrayList g_Nade_HistoryInfo[MAXPLAYERS + 1];  // ArrayList of <int entity, float throw time, int bounces>
  ArrayList g_NadeList;
  ArrayList g_SmokeList;
  ArrayList g_Retake_Players;
  ArrayList g_Retake_Bots;
  ArrayList g_Retake_Retakes;
  ArrayList g_Retake_HoloEnts;
  ArrayList g_Spawns;
  ArrayList g_ChatAliases;
  ArrayList g_ChatAliasesCommands;
  ArrayList g_ClientBots[MAXPLAYERS + 1];  // Bots owned by each client.
  ArrayList g_DemoNadeData[MAXPLAYERS + 1];
  ArrayList g_PredictionResults[MAXPLAYERS + 1];

//

/* ConVar */
  ConVar g_AutostartCvar;
  ConVar g_BotRespawnTimeCvar;
  ConVar g_DryRunFreezeTimeCvar;
  ConVar g_MaxHistorySizeCvar;
  ConVar g_MaxPlacedBotsCvar;
  ConVar g_InfiniteMoneyCvar;
  ConVar g_PatchGrenadeTrajectoryCvar;
  ConVar g_AllowNoclipCvar;
  ConVar g_GlowPMBotsCvar;
  ConVar g_HoloSpawnsCvar;
  ConVar g_Nade_TrajectoryCvar;
  ConVar g_Nade_ThicknessCvar;
  ConVar g_Nade_TimeCvar;
  ConVar g_Nade_SpecTimeCvar;
  ConVar g_FlashEffectiveThresholdCvar;
  ConVar g_TestFlashTeleportDelayCvar;
  ConVar g_VersionCvar;
  ConVar g_Crossfire_MaxBotsCvar;
  ConVar g_Crossfire_MaxPlayersCvar;
  ConVar g_Crossfire_BotAttackTimeCvar;
  ConVar g_Retake_MaxBotsCvar;
  ConVar g_Retake_MaxPlayersCvar;
  ConVar g_Retake_BotReactTimeCvar;
  ConVar g_Retake_BotAttackTimeCvar;
  ConVar g_Retake_BotMoveDistanceCvar;
  ConVar g_Retake_BotSpotMultCvar;
  ConVar g_cBlockPlugins;
  ConVar g_cBlockSM;
//

/* Enum */
  enum E_TimerType {
    TimerType_Increasing_Movement = 0,  // Increasing timer, begins when client moves.
    TimerType_Increasing_Manual = 1,    // Increasing timer, begins as soon as command is run.
    TimerType_Countdown_Movement = 2,   // Countdown, begins when client moves.
  }

  enum GrenadeAccuracyIteratorProp {
    GrenadeAccuracyIteratorProp_Detonation, 
    GrenadeAccuracyIteratorProp_Origin
  }

  enum GrenadeAccuracyScore {
    GrenadeAccuracyScore_GOOD,
    GrenadeAccuracyScore_CLOSE,
    GrenadeAccuracyScore_FAR,
    GrenadeAccuracyScore_IGNORE
  }

  enum E_Nade_MenuType {
    Grenade_MenuType_NadeGroup = 0,
    Grenade_MenuType_TypeFilter = 1
  }

  enum E_Nade_PredictMode {
    Grenade_PredictMode_None = -1,
    Grenade_PredictMode_Normal = 0,
    Grenade_PredictMode_Jumpthrow = 1
  }

  enum E_Manico_RouteType {
    DEFAULT_ROUTE = 0, 
    FASTEST_ROUTE, 
    SAFEST_ROUTE, 
    RETREAT_ROUTE
  }

  enum E_Manico_PriorityType {
    PRIORITY_LOWEST = -1,
    PRIORITY_LOW, 
    PRIORITY_MEDIUM, 
    PRIORITY_HIGH, 
    PRIORITY_UNINTERRUPTABLE
  }

  enum E_Retake_Diff {
    Retake_Diff_Easy = 0,
    Retake_Diff_Medium,
    Retake_Diff_Hard,
    Retake_Diff_VeryHard
  }
//

/* Enum Struct */
  enum struct S_Breakable_Door {
    float origin[3];
    float angles[3];
    // int disableshadows;
    // int distance;
    bool forceclosed;
    char model[128];
    int rendercolor[4];
    float returndelay;
    char slavename[128];
    char soundcloseoverride[128];
    char soundmoveoverride[128];
    char soundopenoverride[128];
    char soundunlockedoverride[128];
    int spawnflags;
    float speed;
    char targetname[MAX_TARGET_LENGTH];
  }

  enum struct S_Breakable_FuncBk {
    float origin[3];
    float angles[3];
    char model[128];
    char targetname[MAX_TARGET_LENGTH];
    RenderMode rendermode;
    // int material;
  }

  enum struct S_Breakable_Dynamic {
    float origin[3];
    float angles[3];
    char model[128];
    int rendercolor[4];
    SolidType_t solidtype;
    SolidFlags_t solidflags;
    int spawnflags;
    char targetname[MAX_TARGET_LENGTH];
  }

  enum struct S_Demo_Match {
    int id;
    char name[128];
    ArrayList roundIds;
  }

  enum struct S_Demo_NadeData {
    float origin[3];
    float angles[3];
    float grenadeOrigin[3];
    float grenadeVelocity[3];
    GrenadeType grenadeType;
    float delay;
  }

  enum struct S_Predict_PredictedPosition {
    char startingPosId[32];
    float origin[3];
    float angles[3];
    char grenadeThrowType[128];
    float airTime;
    float endPos[3];
  }
//

/* KeyValues */
  KeyValues g_NadesKv;  // Inside any global function, we expect this to be at the root level.
  KeyValues g_CrossfiresKv;
  KeyValues g_DemosKv;
  KeyValues g_RetakesKv;
//

/* TypeDef */
  typedef GrenadeIteratorFunction = function Action (
    const char[] ownerName, 
    const char[] ownerAuth, 
    const char[] name, 
    const char[] execution, 
    const char[] grenadeId, 
    float origin[3], 
    float angles[3], 
    const char[] grenadeType, 
    float grenadeOrigin[3],
    float grenadeVelocity[3], 
    float grenadeDetonationOrigin[3], 
    any data
  );
//
