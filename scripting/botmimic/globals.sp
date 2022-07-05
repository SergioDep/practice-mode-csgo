#define PLUGIN_VERSION "3.0"
#define BM_MAGIC 0xdeadbeef
#define BINARY_FORMAT_VERSION 0x03 // New in 0x03 Mimic Demos, Origin based (not velocity)
#define DEFAULT_RECORD_FOLDER "data/botmimic/" // Path for the recordings to be saved.

#define ADDFIELD_TP_ORIGIN (1<<0)
#define ADDFIELD_TP_ANGLES (1<<1)
#define ADDFIELD_TP_VEL (1<<2)

#define EXTRA_PLAYERDATA_HEALTH       (1 << 0)
#define EXTRA_PLAYERDATA_HELMET       (1 << 1)
#define EXTRA_PLAYERDATA_ARMOR        (1 << 2)
#define EXTRA_PLAYERDATA_ON_GROUND    (1 << 3)
#define EXTRA_PLAYERDATA_GRENADE      (1 << 4)
// #define EXTRA_PLAYERDATA_INVENTORY    (1 << 5)
#define EXTRA_PLAYERDATA_EQUIPWEAPON  (1 << 6)
#define EXTRA_PLAYERDATA_MONEY        (1 << 7)
// #define EXTRA_PLAYERDATA_CHAT         (1 << 8)
// SDKHooks_TakeDamage()

// aimbot franc1sco (disable bullets (but create new ones that spawn on head or where it was actually shot ), fake kill feed, dont actually make damage)
// COPY DEMO VARIABLES SERVER: AIRTIME SV_GRAVITY ETC ETC
// spec_show_xray, sv_competitive_official_5v5, sv_specnoclip(?), mp_forcecamera(?)

enum struct S_FrameInfo {
  int PlayerButtons;
  float PlayerOrigin[3];
  float PlayerAngles[3];
  float PlayerVelocity[3];

  int ExtraData;

  int Health;
  bool Helmet;
  int Armor;
  bool OnGround;

  int GrenadeType;
  float GrenadeStartPos[3];
  float GrenadeStartVel[3];

  // int Inventory;
  CSWeaponID ActiveWeapon;

  int Money;
  bool IsScoped;
}

enum struct S_FileData {
  // int teamColor[4];
  // int steamId64; //for crosshair
  int binaryFormatVersion;
  int recordEndTime;
  char playerName[MAX_RECORD_NAME_LENGTH];
  int tickCount;
  int tickRate;
  float playerSpawnPos[3];
  float playerSpawnAng[3];
  ArrayList frames;
}

/* Versus Mode */

#define VersusMode_MaxPositionDiff 50.0
#define VersusMode_ReactTimeMIN 60
#define VersusMode_ReactTimeMAX 300
#define VersusMode_MoveDistanceMIN 60
#define VersusMode_MoveDistanceMAX 150

enum RouteType {
	DEFAULT_ROUTE = 0,
	FASTEST_ROUTE,
	SAFEST_ROUTE,
	RETREAT_ROUTE
}

BMGameMode g_BotMimic_GameMode = BM_GameMode_Spect;
Handle g_hVersusModeMoveTo;
Handle g_hVersusModeIsLineBlockedBySmoke;
Address g_pVersusModeTheBots;
int g_VersusMode_Time[MAXPLAYERS + 1] = {-1, ...};
int g_VersusMode_ReactTime = 120;
int g_VersusMode_MoveDistance = 60;
float g_VersusModeLastMimicPosition[MAXPLAYERS + 1][3];
float g_VersusModeAiStartedTime[MAXPLAYERS + 1];
bool g_VersusModeAiStarted[MAXPLAYERS + 1] = {false, ...};
bool g_VersusModeHandledByAi[MAXPLAYERS + 1] = {false, ...};
bool g_VersusMode_MoveRight[MAXPLAYERS + 1];
bool g_VersusMode_Duck[MAXPLAYERS + 1];
ConVar g_VersusMode_AttackTimeCvar;
// ConVar g_VersusMode_SpotMultCvar;

int g_iServerTickRate = 128;

Handle g_OnPlayerStarsRecordingForward;
Handle g_hfwdOnRecordingPauseStateChanged;
Handle g_OnPlayerStopsRecordingForward;
Handle g_OnRecordSavedForward;
Handle g_OnRecordDeletedForward;
Handle g_OnBotStartsMimicForward;
Handle g_OnBotStopsMimicForward;
Handle g_OnBotMimicLoopsForward;
Handle g_hTeleport;

// delete this, i dont need to pre load the records
StringMap g_hLoadedRecords;
StringMap g_hLoadedRecordsCategory;
ArrayList g_hSortedRecordList;
ArrayList g_hSortedCategoryList;

int g_hRecordingSizeLimit[MAXPLAYERS + 1];
ArrayList g_hRecording[MAXPLAYERS + 1];
bool g_bRecordingPaused[MAXPLAYERS + 1];
int g_iRecordedTicks[MAXPLAYERS + 1];
S_FrameInfo g_iRecordPreviousExtraFrame[MAXPLAYERS + 1];
char g_sRecordName[MAXPLAYERS + 1][MAX_RECORD_NAME_LENGTH];
char g_sRecordPath[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char g_sRecordCategory[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char g_sRecordSubDir[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

ArrayList g_hBotMimicsRecord[MAXPLAYERS + 1] = {null,...};
float g_fInitialPosition[MAXPLAYERS + 1][3];
float g_fInitialAngles[MAXPLAYERS + 1][3];
int g_iBotMimicTick[MAXPLAYERS + 1] = {0,...};
int g_iBotMimicRecordTickCount[MAXPLAYERS + 1] = {0,...};
int g_iBotMimicRecordRunCount[MAXPLAYERS + 1] = {0, ...};
int g_iBotMimicRecordTickRate[MAXPLAYERS + 1] = {128,...};
int g_iBotActiveWeapon[MAXPLAYERS + 1] = {-1,...};
bool g_bBotSwitchedWeapon[MAXPLAYERS + 1];
bool g_bValidTeleportCall[MAXPLAYERS + 1];
bool g_bBotWaitingDelay[MAXPLAYERS + 1];
