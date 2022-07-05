public void OnMapStart() {
  // Clear old records for old map
  int iSize = g_hSortedRecordList.Length;
  char sPath[PLATFORM_MAX_PATH];
  S_FileData rawFileData;
  for(int i=0;i<iSize;i++) {
    g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
    if (!g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData))) {
      PrintToServer("[OnMapStart]Internal state error. %s was in the sorted list, but not in the actual storage.", sPath);
      continue;
    }
    if (rawFileData.frames != null)
      delete rawFileData.frames;
  }
  g_hLoadedRecords.Clear();
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
  g_bRecordingPaused[client] = false;
  g_iRecordedTicks[client] = 0;
  S_FrameInfo iFrame;
  g_iRecordPreviousExtraFrame[client] = iFrame;
  g_sRecordName[client][0] = 0;
  g_sRecordPath[client][0] = 0;
  g_sRecordCategory[client][0] = 0;
  g_sRecordSubDir[client][0] = 0;
  if (g_hBotMimicsRecord[client] != null) BotMimic_StopBotMimicing(client);
  delete g_hBotMimicsRecord[client];
  g_hBotMimicsRecord[client] = null;
  g_iBotMimicTick[client] = 0;
  g_iBotMimicRecordTickCount[client] = 0;
  g_iBotMimicRecordTickRate[client] = g_iServerTickRate;
  g_iBotMimicRecordRunCount[client] = 0;
  g_iBotActiveWeapon[client] = -1;
  g_bBotSwitchedWeapon[client] = false;
  g_bValidTeleportCall[client] = false;
  g_bBotWaitingDelay[client] = false;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (!IsValidClient(client))
    return;

  // Restart moving on spawn!
  if (g_hBotMimicsRecord[client] != null) {
    g_iBotMimicTick[client] = 0;
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
      CreateTimer(0.1, Timer_DelayedRespawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    } else {
      BotMimic_StopBotMimicing(client);
    }
  }
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) {
  Record_RunCmd(client, buttons, angles, weapon);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
  return Mimic_RunCmd(client, buttons, angles, vel, weapon);
}

public void PM_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3], const float velocity[3]) {
  if (!IsValidClient(client) || grenadeType == GrenadeType_None) {
    return;
  }
  if (BotMimic_IsPlayerRecording(client)) {
    // get current (last recorded) frame
    int frameIndex = g_hRecording[client].Length - 1;
    S_FrameInfo iFrame;
    g_hRecording[client].GetArray(frameIndex, iFrame, sizeof(iFrame));
    switch (grenadeType) {
      case GrenadeType_Decoy:
        iFrame.GrenadeType = 501;
      case GrenadeType_Molotov:
        iFrame.GrenadeType = 502;
      case GrenadeType_Incendiary:
        iFrame.GrenadeType = 503;
      case GrenadeType_Flash:
        iFrame.GrenadeType = 504;
      case GrenadeType_Smoke:
        iFrame.GrenadeType = 505;
      case GrenadeType_HE:
        iFrame.GrenadeType = 506;
    }
    iFrame.GrenadeStartPos = origin;
    iFrame.GrenadeStartVel = velocity
    iFrame.ExtraData |= EXTRA_PLAYERDATA_GRENADE;
    g_hRecording[client].SetArray(frameIndex, iFrame, sizeof(iFrame));
  } else if (BotMimic_IsBotMimicing(client)) {
    if (IsValidEntity(entity)) {
      StopSound(entity, SNDCHAN_STATIC, "weapons/smokegrenade/smoke_emit.wav");
      StopSound(entity, SNDCHAN_STATIC, "~)weapons/smokegrenade/smoke_emit.wav");
      StopSound(entity, SNDCHAN_STATIC, "weapons/molotov/fire_loop_1.wav");
      StopSound(entity, SNDCHAN_STATIC, "~)weapons/molotov/fire_loop_1.wav");
      AcceptEntityInput(entity, "Kill");
    }
  }
}
