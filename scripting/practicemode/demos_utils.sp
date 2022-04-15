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

stock void PlayDemo(const char[] demoId, int exclude = -1) {
  if (IsDemoPlaying()) {
    PrintToServer("Called PlayDemo with an active demo!");
    return;
  }
  g_currentDemoGrenade = -1;

  for (int i = 0; i < g_DemoBots.Length; i++) {
    if (i == exclude) {
      continue;
    }
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot) && CheckDemoRoleKVString(demoId, i, "file")) {
      PlayRoleFromDemo(bot, demoId, i);
    }
  }
}

/**
 * Delayed Demo start until after the respawn is done to prevent crashes.
 *
 * @param client          Mimic Client Index.
 * @param filepath        Path for .rec File.
 * @param startDelay      Delay before starting the actual mimic.
 * @error          Not enough variables in datapack.
 * @noreturn
 */
public void StartBotMimicDemo(DataPack pack) {
  pack.Reset();
  int client = pack.ReadCell();
  char filepath[PLATFORM_MAX_PATH];
  pack.ReadString(filepath, sizeof(filepath));
  float startDelay = pack.ReadFloat();

  BMError err = BotMimic_PlayRecordFromFile(client, filepath, startDelay);
  if (err != BM_NoError) {
    char errString[128];
    BotMimic_GetErrorString(err, errString, sizeof(errString));
    PrintToServer("[StartBotMimicDemo]Error playing record %s on client %d: %s", filepath, client, errString);
  }

  delete pack;
}

public void PlayRoleFromDemo(int client, const char[] demoId, int roleId) {
  if (!IsDemoBot(client)) {
    PrintToServer("[PlayRoleFromDemo][ERROR] Called PlayRoleFromDemo on non-demo bot %L", client);
    return;
  }
  if (BotMimic_IsPlayerMimicing(client)) {
    PrintToServer("[PlayRoleFromDemo][ERROR] Called PlayRoleFromDemo on already-demo-playing bot %L", client);
    return;
  }
  char roleIdStr[DEMO_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  char filepath[PLATFORM_MAX_PATH + 1];
  GetDemoRoleKVString(demoId, roleIdStr, "file", filepath, sizeof(filepath));
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
  // CS_SwitchTeam(client, roleTeam);
  // CS_RespawnPlayer(client);
  
  if (GetClientTeam(client) != roleTeam) {
    PrintToServer("LOG: Switched Client %d from %d to roleTeam %d", client, GetClientTeam(client), roleTeam);
    CS_SwitchTeam(client, roleTeam);
  } else {
    PrintToServer("LOG: Client %d is same team(CT = 3, TT = 2) as roleTeam = %d", client, roleTeam);
  }
  if (!IsPlayerAlive(client)) {
    CS_RespawnPlayer(client);
  } else {
    PrintToServer("ERROR: Client %d was alive in PlayRoleFromDemo, prevented crash.", client);
  }
  DataPack pack = new DataPack();
  pack.WriteCell(client);
  pack.WriteString(filepath);
  pack.WriteFloat(0.0);
  RequestFrame(StartBotMimicDemo, pack);
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
    PrintToServer("[GotoDemoRoleStart]Failed to get %s headers: %s", filepath, errorString);
    return;
  }
  TeleportEntity(client, header.BMFH_initialPosition, header.BMFH_initialAngles, {0.0, 0.0, 0.0});
}