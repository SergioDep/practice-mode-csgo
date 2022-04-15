public bool IsPracticeBot(int client) {
  if (g_IsDemoBot[client] || g_IsPMBot[client] || g_IsRetakeBot[client] || g_IsNadeDemoBot[client] || g_IsCrossfireBot[client]) {
    return true;
  }
  return false;
}

public void SetNotPracticeBot(int client) {
  g_IsPMBot[client] = false;
  g_IsRetakeBot[client] = false;
  g_IsDemoBot[client] = false;
  g_IsNadeDemoBot[client] = false;
  g_IsCrossfireBot[client] = false;
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
