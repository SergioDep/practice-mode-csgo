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
//

int g_PracticeSetupClient = -2;
bool g_InPracticeMode = false;
bool g_InDryMode = false;
bool g_InRetakeMode = false;
bool g_InCrossfireMode = false;
bool g_CSUtilsLoaded = false;
bool g_BotMimicLoaded = false;
bool g_InBotDemoMode = false;

Handle HudSync;

// Precache
int g_PredictTrail = -1;
int g_BeamSprite = -1;

// Saved grenade locations data

bool g_CleaningDroppedWeapons = false;
bool g_WaitForServerPassword = false;
bool g_WaitForDemoSave[MAXPLAYERS + 1] = {false, ...};
bool g_WaitForSingleDemoRoleName[MAXPLAYERS + 1] = {false, ...};
bool g_WaitForSingleDemoName[MAXPLAYERS + 1] = {false, ...};
bool g_WaitForSaveNade[MAXPLAYERS + 1] = {false, ...};

int g_recordingNadeDemoStatus[MAXPLAYERS + 1] = {0, ...};// 0 = not recording/canceled, 1 = recording, 2 = not recording/saved
bool g_savedNewNadeDemo[MAXPLAYERS + 1] = {false, ...};
char g_GrenadeLocationsFile[PLATFORM_MAX_PATH];

int g_CurrentSavedGrenadeId[MAXPLAYERS + 1] = {-1, ...};
bool g_UpdatedGrenadeKv = false;  // whether there has been any changed the kv structure this map
int g_NextID = 0;
// int g_currentReplayGrenade = -1;
int g_currentDemoGrenade = -1;

// Grenade history data
int g_GrenadeHistoryIndex[MAXPLAYERS + 1] = {-1, ...};
bool g_TestingFlash[MAXPLAYERS + 1] = {false, ...};
float g_TestingFlashOrigins[MAXPLAYERS + 1][3];
float g_TestingFlashAngles[MAXPLAYERS + 1][3];

bool g_ClientNoFlash[MAXPLAYERS + 1] = {false, ...};
float g_LastFlashDetonateTime[MAXPLAYERS + 1];

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
int g_LastSpecPlayerTeam[MAXPLAYERS + 1] = {-1, ...};

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

const int kMaxBackupsPerMap = 50;

int g_LastNoclipCommand[MAXPLAYERS + 1];


bool g_RunningTimeCommand[MAXPLAYERS + 1];
bool g_RunningLiveTimeCommand[MAXPLAYERS + 1];  // Used by .timer2 & .countdown, gets set to true
                                                // when the client begins moving.
float g_TimerDuration[MAXPLAYERS + 1];  // Used by .countdown, set to the length of the countdown.
TimerType g_TimerType[MAXPLAYERS + 1];
float g_LastTimeCommand[MAXPLAYERS + 1];

// Forwards
Handle g_OnGrenadeSaved = INVALID_HANDLE;
Handle g_OnPracticeModeDisabled = INVALID_HANDLE;
Handle g_OnPracticeModeEnabled = INVALID_HANDLE;

bool g_ClientButtonsInUse[MAXPLAYERS + 1] = {false, ...};

// editor

bool g_UpdatedCrossfireKv = false;
char g_SelectedCrossfireId[OPTION_ID_LENGTH];
bool g_WaitForCrossfireSave[MAXPLAYERS + 1] = {false, ...};

int g_CFMisc_Countdown = -1;
Handle g_CFMisc_CountdownHandle = INVALID_HANDLE;


float g_CFBotSpawnOrigin[MAXPLAYERS + 1][3];
float g_CFBotMaxOrigin[MAXPLAYERS + 1][3];

bool g_CrossfirePlayers_Ready = false;
int g_CFireDeathPlayersCount = 0;
int g_CrossfirePlayers_Points[MAXPLAYERS + 1] = {0, ...};
int g_CrossfirePlayers_Room[MAXPLAYERS + 1] = {-1, ...};


char g_CFireActiveId[OPTION_ID_LENGTH];


// Options
bool g_CFOption_EndlessMode = false;
int g_CFOption_BotsDifficulty = 3;
int g_CFOption_MaxSimBots = 2;
int g_CFOption_BotReactTime = 180;
int g_CFOption_BotStartDelay = 100;
int g_CFOption_BotStrafeChance = 2;
int g_CFOption_BotWeapons = 4;
bool g_CFOption_BotsAttack = true;
bool g_CFOption_BotsFlash = false;
char g_CFMisc_PlayerWeapon[MAXPLAYERS + 1][128];

// Bot Logic
int g_CFBot_StartTime[MAXPLAYERS + 1] = {CFOption_BotStartDelayMIN, ...};
int g_CFBot_Time[MAXPLAYERS + 1];

bool g_CFBotAllowedAttack[MAXPLAYERS + 1] = {false, ...};
bool g_CFireBotDucking[MAXPLAYERS + 1] = {false, ...};
bool g_CFBotStrafe[MAXPLAYERS + 1] = {false, ...};
int g_CFBotStrafeHoldTime[MAXPLAYERS + 1];
bool g_CFBot_Seen[MAXPLAYERS + 1];
int g_CFBot_SeenTime[MAXPLAYERS + 1];
int g_CFBot_SeenTotalTime[MAXPLAYERS + 1];
bool g_CFBot_Moving[MAXPLAYERS + 1];

// NOTE: FULL TIME = REACTTIME + ATTACKTIME
bool g_UpdatedDemoKv = false;
char g_SelectedDemoId[MAXPLAYERS + 1][OPTION_ID_LENGTH];
int g_SelectedRoleId[MAXPLAYERS + 1] = {-1, ...}; //g_CurrentEditingRole[client] = -1;
int g_DemoOption_RoundRestart[MAXPLAYERS + 1] = {0, ...};
int g_CurrentEditingDemoRole[MAXPLAYERS + 1] = {-1, ...};
float g_CurrentDemoRecordingStartTime[MAXPLAYERS + 1];
int g_CurrentDemoNadeIndex[MAXPLAYERS + 1] = {0, ...};
bool g_DemoBotStopped[MAXPLAYERS + 1] = {false, ...}; // g_StopBotSignal
bool g_DemoPlayRoundTimer[MAXPLAYERS + 1] = {false, ...};

bool g_RecordingFullDemo = false;
int g_RecordingFullDemoClient = -1;

bool g_HoloNadeLoadDefault = false;
// ArrayList g_HoloGrenadeIds;
int g_CurrentNadeGroupControl[MAXPLAYERS + 1] = {-1, ...};
int g_CurrentNadeControl[MAXPLAYERS + 1] = {-1, ...};

GrenadeMenuType g_ClientLastMenuType[MAXPLAYERS + 1];
GrenadeType g_ClientLastMenuGrenadeTypeFilter[MAXPLAYERS + 1] = {GrenadeType_None, ...};

bool g_Predict_Debuging[MAXPLAYERS + 1] = {false, ...};

GrenadePredict_Mode g_Predict_LastMode[MAXPLAYERS + 1] = {GRENADEPREDICT_NONE, ...};
GrenadeType g_Predict_LastGrenadeEquiped[MAXPLAYERS + 1] = {GrenadeType_None, ...};
bool g_Predict_LastCrouch[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_Allowed[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_HoldingUse[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_HoldingReload[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_ViewEndpoint[MAXPLAYERS + 1] = {false, ...};
int g_Predict_ObservingGrenade[MAXPLAYERS + 1] = {-2, ...};
int g_Predict_FinalDestinationEnt[MAXPLAYERS + 1] = {-1, ...};
int g_Predict_GenerateViewPointDelay[MAXPLAYERS + 1] = {GenerateViewPointDelay, ...};
float g_Predict_LastClientViewPos[MAXPLAYERS + 1][3]; // g_LastGrenadePinPulledOrigin
float g_Predict_LastClientAng[MAXPLAYERS + 1][3];
float g_Predict_LastClientViewAng[MAXPLAYERS + 1][3];

// database
Database g_PredictionDb = null;
int g_Prediction_CurrentLineup[MAXPLAYERS + 1] = {-1, ...};
float g_PredictionClientPos[MAXPLAYERS + 1][3];

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

bool g_manicoBombPlanted;
bool g_manicoEveryoneDead;
bool g_IsDemoVersusBot[MAXPLAYERS + 1];
bool g_manicoZoomed[MAXPLAYERS + 1];
bool g_manicoDontSwitch[MAXPLAYERS + 1];
int g_manicoUncrouchChance[MAXPLAYERS + 1];
int g_manicoTarget[MAXPLAYERS + 1];
int g_manicoBotTargetSpotOffset;
int g_manicoBotNearbyEnemiesOffset;
int g_manicoFireWeaponOffset;
int g_manicoEnemyVisibleOffset;
int g_manicoBotProfileOffset;
int g_manicoBotEnemyOffset;
int g_manicoBotMoraleOffset;
float g_manicoTargetPos[MAXPLAYERS + 1][3];
float g_manicoNadeTarget[MAXPLAYERS + 1][3];
float g_manicoLookAngleMaxAccel[MAXPLAYERS + 1];
float g_manicoReactionTime[MAXPLAYERS + 1];
Handle g_manicoBotMoveTo;
Handle g_manicoLookupBone;
Handle g_manicoGetBonePosition;
Handle g_manicoBotIsVisible;
Handle g_manicoBotIsHiding;
Handle g_manicoBotEquipBestWeapon;
Handle g_manicoSwitchWeaponCall;
Handle g_manicoIsLineBlockedBySmoke;
Handle g_manicoBotBendLineOfSight;
Address g_manicoTheBots;
CNavArea g_manicoCurrArea[MAXPLAYERS + 1];

int bombTicking;
int g_RKBot_Time[MAXPLAYERS + 1] = {0, ...};
int g_RetakeBotDirection[MAXPLAYERS + 1];
int g_RetakeBotDuck[MAXPLAYERS + 1];
// int g_RetakeBotWalk[MAXPLAYERS + 1];
int g_RetakeDeathPlayersCount = 0;
int g_RetakePlayers_Points[MAXPLAYERS + 1] = {0, ...};
char g_RetakePlayId[OPTION_ID_LENGTH];

bool g_UpdatedRetakeKv = false;
char g_SelectedRetakeId[OPTION_ID_LENGTH];
bool g_WaitForRetakeSave[MAXPLAYERS + 1] = {false, ...};
RetakeDifficulty g_RetakeDifficulty = RetakeDiff_Medium;

int ctSpawnsLength;

ConVar g_cBlockPlugins = null;
ConVar g_cBlockSM = null;

char g_sLogs[PLATFORM_MAX_PATH + 1];


bool AFK_autoCheck;
bool AFK_Warned[MAXPLAYERS + 1] = {false, ...};
float AFK_LastCheckTime[MAXPLAYERS + 1] = {0.0, ...};
float AFK_LastMovementTime[MAXPLAYERS + 1] = {0.0, ...};
float AFK_LastEyeAngle[MAXPLAYERS + 1][3];
float AFK_LastPosition[MAXPLAYERS + 1][3];
Handle AFK_AdminImmune = INVALID_HANDLE;
Handle AFK_TimerDelay = INVALID_HANDLE;
Handle AFK_MaxTime = INVALID_HANDLE;
Handle hSvPasswordChangeCallback;

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////

/* Ints */
  int g_BotPlayerModels[MAXPLAYERS + 1] = {-1, ...};
  int g_BotPlayerModelsIndex[MAXPLAYERS + 1] = {-1, ...};
  int g_CurrentBotControl[MAXPLAYERS + 1] = {-1, ...};
//

/* ArrayList */
  ArrayList g_GrenadeHistoryPositions[MAXPLAYERS + 1];
  ArrayList g_GrenadeHistoryAngles[MAXPLAYERS + 1];
  ArrayList g_ClientGrenadeThrowTimes[MAXPLAYERS + 1];  // ArrayList of <int entity, float throw time, int bounces>
  ArrayList g_ClientBots[MAXPLAYERS + 1];  // Bots owned by each client.
  ArrayList RespawnEnts_propdoorrotating;
  ArrayList RespawnEnts_funcbreakable;
  ArrayList RespawnEnts_propdynamic;
  ArrayList g_HoloCFireEnts;
  ArrayList g_CrossfirePlayers;
  ArrayList g_CrossfireBots;
  ArrayList g_CFireArenas;
  ArrayList g_DemoBots;
  ArrayList g_DemoNadeData[MAXPLAYERS + 1];
  ArrayList g_HoloNadeEntities;
  ArrayList g_EnabledHoloNadeAuth;
  ArrayList g_PredictionResults[MAXPLAYERS + 1];
  ArrayList g_RetakePlayers;
  ArrayList g_RetakeBots;
  ArrayList g_RetakeRetakes;
  ArrayList g_HoloRetakeEntities;
  ArrayList g_Spawns;
  ArrayList g_ChatAliases;
  ArrayList g_ChatAliasesCommands;
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
  ConVar g_GrenadeTrajectoryCvar;
  ConVar g_GrenadeThicknessCvar;
  ConVar g_GrenadeTimeCvar;
  ConVar g_GrenadeSpecTimeCvar;
  ConVar g_FlashEffectiveThresholdCvar;
  ConVar g_TestFlashTeleportDelayCvar;
  ConVar g_VersionCvar;
  ConVar g_MaxCrossfireBotsCvar;
  ConVar g_MaxCrossfirePlayersCvar;
  ConVar g_CFBot_AttackTimeCvar; // usefull for sprays
  ConVar g_MaxRetakeBotsCvar;
  ConVar g_MaxRetakePlayersCvar;
  // NOTE: RKBOT_REACTTIME > RKBOT_MOVEDISTANCE && RKBOT_MOVEDISTANCE > 0
  ConVar g_RKBot_ReactTimeCvar; // how long until he shoots
  // NOTE: FULL TIME = REACTTIME + ATTACKTIME
  ConVar g_RKBot_AttackTimeCvar; // usefull for sprays
  ConVar g_RKBot_MoveDistanceCvar; // usefull for distance
  ConVar g_RKBot_SpotMultCvar;
//

/* Enum */
  enum TimerType {
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

  enum GrenadeMenuType {
    GrenadeMenuType_NadeGroup = 0,
    GrenadeMenuType_TypeFilter = 1
  }

  enum GrenadePredict_Mode {
    GRENADEPREDICT_NONE = -1,
    GRENADEPREDICT_NORMAL = 0,
    GRENADEPREDICT_JUMPTHROW = 1
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

  enum RetakeDifficulty {
    RetakeDiff_Easy = 0,
    RetakeDiff_Medium,
    RetakeDiff_Hard,
    RetakeDiff_VeryHard
  }
//

/* Enum Struct */
  enum struct B_PropDoorRotating {
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

  enum struct B_FuncBreakable {
    float origin[3];
    float angles[3];
    char model[128];
    char targetname[MAX_TARGET_LENGTH];
    RenderMode rendermode;
    // int material;
  }

  enum struct B_PropDynamic {
    float origin[3];
    float angles[3];
    char model[128];
    int rendercolor[4];
    SolidType_t solidtype;
    SolidFlags_t solidflags;
    int spawnflags;
    char targetname[MAX_TARGET_LENGTH];
  }

  enum struct DemoNadeData {
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
  KeyValues g_GrenadeLocationsKv;  // Inside any global function, we expect this to be at the root level.
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
