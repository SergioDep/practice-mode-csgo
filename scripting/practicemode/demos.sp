#define DEMO_ID_LENGTH 16
#define DEMO_NAME_LENGTH 128

#define MAX_DEMO_BOTS 5

bool g_UpdatedDemoKv = false;
char g_SelectedDemoId[MAXPLAYERS + 1][DEMO_ID_LENGTH];
int g_SelectedRoleId[MAXPLAYERS + 1] = {-1, ...}; //g_CurrentEditingRole[client] = -1;
int g_CurrentEditingDemoRole[MAXPLAYERS + 1] = {-1, ...};
int g_IsDemoBot[MAXPLAYERS + 1] = {0, ...}; //0 = not a replay bot, else role number
float g_CurrentDemoRecordingStartTime[MAXPLAYERS + 1];
int g_CurrentDemoNadeIndex[MAXPLAYERS + 1] = {0, ...};
bool g_DemoBotStopped[MAXPLAYERS + 1] = {false, ...}; // g_StopBotSignal
bool g_DemoPlayRoundTimer[MAXPLAYERS + 1] = {false, ...};

bool g_RecordingFullDemo = false;
int g_RecordingFullDemoClient = -1;

ArrayList g_DemoBots;

// Nade DemoBot Data
ArrayList g_DemoNadeData[MAXPLAYERS + 1];

enum struct DemoNadeData {
  float origin[3];
  float angles[3];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  GrenadeType grenadeType;
  float delay;
}

public void Demos_PluginStart() {
  g_DemoBots = new ArrayList();
}

public void Demos_MapStart() {
  delete g_DemosKv;
  g_DemosKv = new KeyValues("Demos");

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char demoFile[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, demoFile, sizeof(demoFile), "data/practicemode/demos/%s.cfg", map);
  g_DemosKv.ImportFromFile(demoFile);

  for (int i = 0; i <= MaxClients; i++) {
    delete g_DemoNadeData[i];
    g_DemoNadeData[i] = new ArrayList(sizeof(DemoNadeData));
    // g_DemoPlayRoundTimer[i] = false; it starts with false
  }
}

public void Demos_MapEnd() {
  MaybeWriteNewDemoData();
}

public void Demos_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3], const float velocity[3]) {
  if (!g_BotMimicLoaded) {
    return;
  }

  if (g_CurrentEditingDemoRole[client] >= 0 && BotMimic_IsPlayerRecording(client)) {
    DemoNadeData demoNadeData;
    demoNadeData.delay = GetGameTime() - g_CurrentDemoRecordingStartTime[client];
    GetClientAbsOrigin(client, demoNadeData.origin);
    GetClientEyeAngles(client, demoNadeData.angles);
    demoNadeData.grenadeOrigin = origin;
    demoNadeData.grenadeType = grenadeType;
    demoNadeData.grenadeVelocity = velocity;
    g_DemoNadeData[client].PushArray(demoNadeData, sizeof(demoNadeData));
    if (demoNadeData.delay < 1.27) {  // Takes 1.265625s to pull out a grenade.
      PM_Message(
          client,
          "{LIGHT_RED}Advertencia: {NORMAL}Tirar una granada justo despues de empezar la grabación puede no guardarla. {LIGHT_RED}Espera un segundo {NORMAL}despues de empezar la grabacion para tirar la granada.");
    }
  }

  if (BotMimic_IsPlayerMimicing(client)) {
    int index = g_CurrentDemoNadeIndex[client];
    if (index < g_DemoNadeData[client].Length) {
      DemoNadeData demoNadeData;
      g_DemoNadeData[client].GetArray(index, demoNadeData, sizeof(demoNadeData));
      TeleportEntity(entity, demoNadeData.grenadeOrigin, NULL_VECTOR, demoNadeData.grenadeVelocity);
      g_CurrentDemoNadeIndex[client]++;
    }
  }
}

public void ExitDemoMode() {
  ServerCommand("bot_kick");
  g_DemoBots.Clear();
  for (int i = 0; i < g_DemoBots.Length; i++) {
    g_IsDemoBot[g_DemoBots.Get(i)] = 0;
  }
  g_InBotDemoMode = false;
  g_RecordingFullDemo = false;
  ChangeSettingById("respawning", true);
  // ServerCommand("mp_death_drop_gun 0");

  PM_MessageToAll("Modo Demos desactivado.");
}

public void InitDemoFunctions() {
  ResetDemoClientsData();
  for (int i = 0; i <= MaxClients; i++) {
    g_IsDemoBot[i] = 0; //g_ReplayBotClients[i] = -1;
  }
  g_DemoBots.Clear();

  GetDemoBots();

  g_InBotDemoMode = true;
  g_RecordingFullDemo = false;

  // Settings we need to have the mode work
  ChangeSettingById("respawning", false);
  // ServerCommand("mp_death_drop_gun 1"); WHY??????

  PM_MessageToAll("Modo Demos Activado.");
}

public void ResetDemoClientsData() {
  for (int i = 0; i <= MaxClients; i++) {
    g_DemoBotStopped[i] = false;
    g_CurrentEditingDemoRole[i] = -1;
    g_SelectedDemoId[i] = "";
  }
}

public void GetDemoBots() {
  ServerCommand("bot_quota_mode normal");
  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    ServerCommand("bot_add");
  }

  CreateTimer(0.1, Timer_GetDemoBots);
}

public Action Timer_GetDemoBots(Handle timer) {
  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    char name[MAX_NAME_LENGTH];
    Format(name, sizeof(name), "Demo Bot %d", i + 1);
    if (i < g_DemoBots.Length) {
      if (IsDemoBot(g_DemoBots.Get(i))) {
        continue;
      }
    }
    int bot = GetLiveBot(name);
    g_IsDemoBot[bot] = true;
    g_DemoBots.Push(bot); // g_ReplayBotClients[i] = GetLiveBot(name);
  }
  return Plugin_Handled;
}

public Action Command_Demos(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }

  if (!g_BotMimicLoaded) {
    PrintToServer("You need the botmimic plugin loaded to use demo functions.");
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PrintToServer("You need the csutils plugin loaded to use demo functions.");
    return Plugin_Handled;
  }

  if (!g_InBotDemoMode) {
    InitDemoFunctions();
  }

  if (args >= 1) {
    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));
    if (DemoExists(arg)) {
      strcopy(g_SelectedDemoId[client], DEMO_ID_LENGTH, arg);
      SingleDemoEditorMenu(client);
    } else {
      PM_Message(client, "No existe demo con id %s.", arg);
    }

    return Plugin_Handled;
  }

  GiveDemoMenuInContext(client);
  return Plugin_Handled;
}

public void GiveDemoMenuInContext(int client) {
  if (DemoExists(g_SelectedDemoId[client])) {
    if (g_CurrentEditingDemoRole[client] >= 0) {
      // Demo-role specific menu.
      SingleDemoRoleMenu(client, g_CurrentEditingDemoRole[client]);
    } else {
      // Demo-specific menu.
      SingleDemoEditorMenu(client);
    }
  } else {
    // All Demos menu.
    DemosEditorMenu(client);
  }
}

public bool IsDemoBot(int client) {
  return client > 0 && g_IsDemoBot[client] && IsClientInGame(client) && IsFakeClient(client);
}

public void BotMimic_OnPlayerMimicLoops(int client) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return;
  }

  if (g_InBotReplayMode) {
    if (g_StopBotSignal[client]) {
      if(!versusMode){
        BotMimic_ResetPlayback(client);
        BotMimic_StopPlayerMimic(client);
        RequestFrame(Timer_DelayKillBot, GetClientSerial(client));
      }
    } else {
      g_StopBotSignal[client] = true;
    }
  } else if (g_InBotDemoMode) {
    if (g_DemoBotStopped[client]) {
        // BotMimic_ResetPlayback(client);
        PrintToChatAll("stopstopstopstopstop");
        BotMimic_StopPlayerMimic(client);
    } else {
      g_DemoBotStopped[client] = true;
    }
  }
  

  // if (g_IsHoloNadeBot[client]) {
  //   BotMimic_StopPlayerMimic(client);
  //   KickClient(client);
  // }
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// BOTREPLAYS.EDITOR
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
public void BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file) {
  if (g_InBotDemoMode) {
    if (g_CurrentEditingDemoRole[client] >= 0) {
      char roleIdStr[DEMO_ID_LENGTH];
      IntToString(g_CurrentEditingDemoRole[client], roleIdStr, sizeof(roleIdStr));
      SetDemoRoleKVString(g_SelectedDemoId[client], roleIdStr, "file", file);
      SetDemoRoleKVNades(client, g_SelectedDemoId[client], roleIdStr);
      SetDemoRoleKVString(g_SelectedDemoId[client], roleIdStr, "team", GetClientTeam(client) == CS_TEAM_CT ? "CT" : "T");

      if (!g_RecordingFullDemo) {
        PM_Message(client, "{ORANGE}Terminó la grabación de jugador rol %d", g_CurrentEditingDemoRole[client] + 1);
        GiveDemoMenuInContext(client);
      } else {
        if (g_RecordingFullDemoClient == client) {
          g_CurrentEditingDemoRole[client] = -1;
          PM_MessageToAll("{ORANGE}Terminó la grabación completa de esta demo.");
          RequestFrame(ResetFullDemoRecording, GetClientSerial(client));
        }
      }
      MaybeWriteNewDemoData();
    }
    return;
  } else if (g_InBotReplayMode) {
    if (g_CurrentEditingRole[client] >= 0) {
      SetRoleFile(g_ReplayId[client], g_CurrentEditingRole[client], file);
      SetRoleNades(g_ReplayId[client], g_CurrentEditingRole[client], client);
      SetRoleTeam(g_ReplayId[client], g_CurrentEditingRole[client], GetClientTeam(client));

      if (!g_RecordingFullReplay) {
        PM_Message(client, "Terminó la grabación de jugador rol %d", g_CurrentEditingRole[client] + 1);
        GiveReplayMenuInContext(client);
      } else {
        if (g_RecordingFullReplayClient == client) {
          g_CurrentEditingRole[client] = -1;
          PM_MessageToAll("Terminó la grabación completa de esta repetición.");
          RequestFrame(ResetFullReplayRecording, GetClientSerial(client));
        }
      }

      MaybeWriteNewReplayData();
    }
    return;
  }

  PM_Message(client, "saved: current: %d, file %s", g_CurrentSavedGrenadeId[client], file);
  SetClientGrenadeData(g_CurrentSavedGrenadeId[client], "record", file);
  MaybeWriteNewGrenadeData();
}

public void ResetFullDemoRecording(int serial) {
  g_RecordingFullDemo = false;
  g_RecordingFullDemoClient = -1;
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
    GiveDemoMenuInContext(client);
  }
}

public Action Command_FinishRecordingDemo(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  FinishRecordingDemo(client, true);
  return Plugin_Handled;
}

void FinishRecordingDemo(int client, bool printOnFail) {
  if (g_RecordingFullDemo) {
    for (int i = 0; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(i, true /* save */);
      }
    }

  } else {
    if (BotMimic_IsPlayerRecording(client)) {
      BotMimic_StopRecording(client, true /* save */);
    } else if (printOnFail) {
      PM_Message(client, "No estas grabando una demo ahora mismo.");
    }
  }
}

public Action Command_DemoCancel(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int numActiveDemos = 0;
  for (int i = 0; i < g_DemoBots.Length; i++) {
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot) && BotMimic_IsPlayerMimicing(bot)) {
      numActiveDemos++;
    }
  }

  if (g_RecordingFullDemo) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(client, false /* save */);
      }
    }
  } else if (BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);
  } else if (numActiveDemos > 0) {
    CancelAllDemos();
    PM_MessageToAll("Cancelled all demos.");
  }

  return Plugin_Handled;
}

stock void StartDemoRecording(int client, int roleId, bool printCommands = true) {
  if (roleId < 0 || roleId >= g_DemoBots.Length) {
    return;
  }

  g_DemoNadeData[client].Clear();
  g_CurrentEditingDemoRole[client] = roleId;
  g_CurrentDemoRecordingStartTime[client] = GetGameTime();

  char recordName[128];
  Format(recordName, sizeof(recordName), "Rol de jugador %d", roleId + 1);
  char roleString[32];
  Format(roleString, sizeof(roleString), "rol %d", roleId);
  BotMimic_StartRecording(client, recordName, "practicemode", roleString);

  if (g_DemoPlayRoundTimer[client]) {
    float timer_duration = float(GetRoundTimeSeconds());
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = true;
    g_TimerType[client] = TimerType_Countdown_Movement;
    g_TimerDuration[client] = timer_duration;
    StartClientTimer(client);
  }

  if (printCommands) {
    PM_Message(client, "{ORANGE}Grabación de jugador %d empezada.", roleId + 1);
    PM_Message(client, "{ORANGE}Usa .finish o activa noclip para dejar de grabar.");
  }
}
