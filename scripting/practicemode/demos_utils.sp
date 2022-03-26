// Cancels all current playing demos.
public void CancelAllDemos() {
  for (int i = 0; i < g_DemoBots.Length; i++) {
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot) && BotMimic_IsPlayerMimicing(bot)) {
      BotMimic_StopPlayerMimic(bot);
      // RequestFrame(Timer_DelayKillBot, GetClientSerial(g_ReplayBotClients[i]));
    }
  }
}

// Returns if a demo is currently playing.
stock bool IsDemoPlaying(int role = -1) {
  for (int i = 0; i < g_DemoBots.Length; i++) {
    if (role != -1 && role != i) {
      continue;
    }

    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot) && BotMimic_IsPlayerMimicing(bot)) return true; //(versusMode && IsPlayerAlive(bot)
  }
  return false;
}

stock void RunDemo(const char[] demoId, int exclude = -1) {
  if (IsDemoPlaying()) {
    LogError("Called RunDemo with an active demo!");
    return;
  }
  g_currentDemoGrenade = -1;

  for (int i = 0; i < g_DemoBots.Length; i++) {
    if (i == exclude) {
      continue;
    }
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot) && CheckDemoRoleKVString(demoId, i, "file")) {
      PlayDemoRole(bot, demoId, i);
    }
  }
}

// Delayed Demo start until after the respawn is done to prevent crashes.
// TOOD: see if we really need this.
public void StartDemo(DataPack pack) {
  pack.Reset();
  int client = pack.ReadCell();
  char filepath[PLATFORM_MAX_PATH];
  pack.ReadString(filepath, sizeof(filepath));
  PrintToChatAll("read filepath %s", filepath);

  BMError err = BotMimic_PlayRecordFromFile(client, filepath);
  PrintToChatAll("errortttttype on client %d %N = %d", client, client, err);
  if (err != BM_NoError) {
    char errString[128];
    BotMimic_GetErrorString(err, errString, sizeof(errString));
    LogError("Error playing record %s on client %d: %s", filepath, client, errString);
  }

  delete pack;
}

public void PlayDemoRole(int client, const char[] demoId, int roleId) {
  if (!IsDemoBot(client)) {
    PrintToServer("[ERROR] Called PlayDemoRole on non-demo bot %L", client);
    return;
  }
  if (BotMimic_IsPlayerMimicing(client)) {
    PrintToServer("[ERROR] Called PlayDemoRole on already-demo-playing bot %L", client);
    return;
  }
  char roleIdStr[DEMO_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  char filepath[PLATFORM_MAX_PATH + 1];
  GetDemoRoleKVString(demoId, roleIdStr, "file", filepath, sizeof(filepath));
  PrintToChatAll("%s got filepath %s end", roleIdStr, filepath);
  GetDemoRoleKVNades(client, demoId, roleIdStr);

  char roleName[DEMO_NAME_LENGTH];
  if (GetDemoRoleKVString(demoId, roleIdStr, "name", roleName, sizeof(roleName))) {
    // TODO: format [DEMOBOT]
    SetClientName(client, roleName);
  }

  int roleTeam;
  g_CurrentDemoNadeIndex[client] = 0;
  char roleTeamStr[DEMO_ID_LENGTH];
  GetDemoRoleKVString(demoId, roleIdStr, "team", roleTeamStr, sizeof(roleTeamStr));
  roleTeam = view_as<int>(StrEqual(roleTeamStr, "CT")) + 2; // 0 + 2 = 2 = cs_team_t 1 + 2 = 3 = cs_team_ct
  CS_SwitchTeam(client, roleTeam);
  CS_RespawnPlayer(client);
  DataPack pack = new DataPack();
  pack.WriteCell(client);
  pack.WriteString(filepath);
  PrintToChatAll("requestframe client %d filepath %s end", client, filepath);
  RequestFrame(StartDemo, pack);
  g_DemoBotStopped[client] = false;
  g_CurrentDemoNadeIndex[client] = 0;
}

// Teleports a client to the point where a demo begins.
public void GotoDemoRoleStart(int client, const char[] demoId, int roleId) {
  char filepath[PLATFORM_MAX_PATH + 1];
  char roleIdStr[DEMO_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  GetDemoRoleKVString(demoId, roleIdStr, "file", filepath, sizeof(filepath));
  BMFileHeader header;
  BMError error = BotMimic_GetFileHeaders(filepath, header, sizeof(header));
  if (error != BM_NoError) {
    char errorString[128];
    BotMimic_GetErrorString(error, errorString, sizeof(errorString));
    LogError("Failed to get %s headers: %s", filepath, errorString);
    return;
  }
  TeleportEntity(client, header.BMFH_initialPosition, header.BMFH_initialAngles, {0.0, 0.0, 0.0});
}