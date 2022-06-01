public bool IsPracticeBot(int client) {
  if (g_IsPMBot[client] || g_IsRetakeBot[client] || g_IsDemoBot[client] || g_IsNadeDemoBot[client] || g_IsCrossfireBot[client]) {
    return true;
  }
  return false;
}

public void SetNotPracticeBot(int bot) {
  g_IsPMBot[bot] = false;
  g_IsRetakeBot[bot] = false;
  g_IsDemoBot[bot] = false;
  g_IsNadeDemoBot[bot] = false;
  g_IsCrossfireBot[bot] = false;
  g_BotMindControlOwner[bot] = -1;
  g_IsDemoVersusBot[bot] = false;
  strcopy(g_BotOriginalName[bot], sizeof(g_BotOriginalName[]), "-1");
}

public int GetLargestBotUserId() {
  int largestUserid = -1;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && IsFakeClient(i) && !IsClientSourceTV(i)) {
      int userid = GetClientUserId(i);
      if (userid > largestUserid && !IsPracticeBot(i)) {
        largestUserid = userid;
      }
    }
  }
  return largestUserid;
}

stock int GetLiveBot(int changeTeam = CS_TEAM_NONE) {
  int largestUserid = GetLargestBotUserId();
  if (largestUserid == -1) {
    return -1;
  }

  int bot = GetClientOfUserId(largestUserid);
  if (!IsValidClient(bot)) {
    return -1;
  }

  if (changeTeam > CS_TEAM_SPECTATOR) {
    ChangeClientTeam(bot, changeTeam);
    ForcePlayerSuicide(bot);
    CS_RespawnPlayer(bot);
  }

  return bot;
}
