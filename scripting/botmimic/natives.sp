public int Native_StartRecording(Handle plugin, int numParams) {
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

  g_hRecording[client] = new ArrayList(sizeof(S_FrameInfo));
  GetClientAbsOrigin(client, g_fInitialPosition[client]);
  GetClientEyeAngles(client, g_fInitialAngles[client]);
  g_iRecordedTicks[client] = 0;

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
  Call_StartForward(g_OnPlayerStarsRecordingForward);
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

public int Native_StopRecording(Handle plugin, int numParams) {
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
  Call_StartForward(g_OnPlayerStopsRecordingForward);
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
    S_FileData iHeader;
    iHeader.binaryFormatVersion = BINARY_FORMAT_VERSION;
    iHeader.recordEndTime = iEndTime;
    iHeader.tickCount = g_hRecording[client].Length;
    iHeader.tickRate = g_iServerTickRate;
    strcopy(iHeader.playerName, MAX_RECORD_NAME_LENGTH, g_sRecordName[client]);
    Array_Copy(g_fInitialPosition[client], iHeader.playerSpawnPos, 3);
    Array_Copy(g_fInitialAngles[client], iHeader.playerSpawnAng, 3);
    iHeader.frames = g_hRecording[client];
    
    WriteRecordToDisk(sPath, iHeader);
    
    g_hLoadedRecords.SetArray(sPath, iHeader, sizeof(iHeader));
    g_hLoadedRecordsCategory.SetString(sPath, g_sRecordCategory[client]);
    g_hSortedRecordList.PushString(sPath);
    if (g_hSortedCategoryList.FindString(g_sRecordCategory[client]) == -1)
      g_hSortedCategoryList.PushString(g_sRecordCategory[client]);
    SortRecordList();
    
    Call_StartForward(g_OnRecordSavedForward);
    Call_PushCell(client);
    Call_PushString(g_sRecordName[client]);
    Call_PushString(g_sRecordCategory[client]);
    Call_PushString(g_sRecordSubDir[client]);
    Call_PushString(sPath);
    Call_Finish();
  } else {
    delete g_hRecording[client];
  }

  g_hRecording[client] = null;
  g_hRecordingSizeLimit[client] = -1;
  g_iRecordedTicks[client] = 0;
  S_FrameInfo iFrame;
  g_iRecordPreviousExtraFrame[client] = iFrame;
  g_sRecordName[client][0] = 0;
  g_sRecordPath[client][0] = 0;
  g_sRecordCategory[client][0] = 0;
  g_sRecordSubDir[client][0] = 0;
  g_bRecordingPaused[client] = false;
  return 0;
}

public int Native_IsPlayerRecording(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return false;
  }

  return g_hRecording[client] != null;
}

public int Native_ResumeRecording(Handle plugin, int numParams) {
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

  g_bRecordingPaused[client] = false;

  Call_StartForward(g_hfwdOnRecordingPauseStateChanged);
  Call_PushCell(client);
  Call_PushCell(false);
  Call_Finish();
  return 0;
}

public int Native_PauseRecording(Handle plugin, int numParams) {
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

public int Native_IsRecordingPaused(Handle plugin, int numParams) {
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

public int Native_DeleteRecord(Handle plugin, int numParams) {
  int iLen;
  GetNativeStringLength(1, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(1, sPath, iLen+1);

  // Do we have this record loaded?
  S_FileData rawFileData;
  if (!g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData))) {
    if (!FileExists(sPath))
      return -1;
    
    // Try to load it to make sure it's a record file we're deleting here!
    BMError error = LoadRecordFromFile(sPath, DEFAULT_CATEGORY, rawFileData, true, false);
    if (error == BM_FileNotFound || error == BM_BadFile)
      return -1;
  }

  int iCount;
  if (rawFileData.frames != null) {
    for(int i=1;i<=MaxClients;i++) {
      // Stop the bots from mimicing this one
      if (g_hBotMimicsRecord[i] == rawFileData.frames) {
        BotMimic_StopBotMimicing(i);
        iCount++;
      }
    }
    
    // Discard the frames
    delete rawFileData.frames;
  }

  char sCategory[64];
  g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory));

  g_hLoadedRecords.Remove(sPath);
  g_hLoadedRecordsCategory.Remove(sPath);
  g_hSortedRecordList.Erase(g_hSortedRecordList.FindString(sPath));

  // Delete the file
  if (FileExists(sPath)) {
    DeleteFile(sPath);
  }

  Call_StartForward(g_OnRecordDeletedForward);
  Call_PushString(rawFileData.playerName);
  Call_PushString(sCategory);
  Call_PushString(sPath);
  Call_Finish();

  return iCount;
}

public int Native_PlayRecordFromFile(Handle plugin, int numParams) {
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

public int Native_PlayRecordByName(Handle plugin, int numParams) {
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
  S_FileData rawFileData;
  int iRecentTimeStamp;
  char sRecentPath[PLATFORM_MAX_PATH];
  for(int i=0;i<iSize;i++) {
    g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
    g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData));
    if (StrEqual(sName, rawFileData.playerName)) {
      if (iRecentTimeStamp == 0 || iRecentTimeStamp < rawFileData.recordEndTime)
      {
        iRecentTimeStamp = rawFileData.recordEndTime;
        strcopy(sRecentPath, sizeof(sRecentPath), sPath);
      }
    }
  }

  if (!iRecentTimeStamp || !FileExists(sRecentPath))
    return view_as<int>(BM_FileNotFound);

  return view_as<int>(PlayRecord(client, sRecentPath, startDelay));
}

public int Native_IsBotMimicing(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return false;
  }

  return g_hBotMimicsRecord[client] != null;
}

public int Native_ResetMimic(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (!BotMimic_IsBotMimicing(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
    return 0;
  }

  g_iBotMimicTick[client] = 0;
  g_bValidTeleportCall[client] = false;
  return 0;
}

public int Native_StopBotMimicing(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (!BotMimic_IsBotMimicing(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
    return 0;
  }
  char sPath[PLATFORM_MAX_PATH];
  GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));

  g_hBotMimicsRecord[client] = null;
  g_iBotMimicTick[client] = 0;
  g_iBotMimicRecordTickCount[client] = 0;
  g_iBotMimicRecordTickRate[client] = g_iServerTickRate;
  g_iBotMimicRecordRunCount[client] = 0;
  g_bValidTeleportCall[client] = false;

  // Versus Mode
  g_VersusModeHandledByAi[client] = false;
  g_VersusModeAiStarted[client] = false;
  g_VersusMode_Time[client] = -1;

  S_FileData rawFileData;
  g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData));

  SDKUnhook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);

  char sCategory[64];
  g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory));

  Call_StartForward(g_OnBotStopsMimicForward);
  Call_PushCell(client);
  Call_PushString(rawFileData.playerName);
  Call_PushString(sCategory);
  Call_PushString(sPath);
  Call_Finish();
  return 0;
}

public int Native_GetMimicFileFromBot(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client < 1 || client > MaxClients || !IsClientInGame(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
    return 0;
  }

  if (!BotMimic_IsBotMimicing(client)) {
    ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
    return 0;
  }

  int iLen = GetNativeCell(3);
  char[] sPath = new char[iLen];
  GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, iLen);
  SetNativeString(2, sPath, iLen);
  return 0;
}

public int Native_GetFileHeaders(Handle plugin, int numParams) {
  int iLen;
  GetNativeStringLength(1, iLen);
  char[] sPath = new char[iLen+1];
  GetNativeString(1, sPath, iLen+1);

  if (!FileExists(sPath)) {
    return view_as<int>(BM_FileNotFound);
  }

  S_FileData rawFileData;
  if (!g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData))) {
    char sCategory[64];
    if (!g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
      strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
    BMError error = LoadRecordFromFile(sPath, sCategory, rawFileData, true, false);
    if (error != BM_NoError)
      return view_as<int>(error);
  }

  BMFileHeader iExposedFileHeader;
  iExposedFileHeader.binaryFormatVersion = rawFileData.binaryFormatVersion;
  iExposedFileHeader.recordEndTime = rawFileData.recordEndTime;
  strcopy(iExposedFileHeader.playerName, MAX_RECORD_NAME_LENGTH, rawFileData.playerName);
  iExposedFileHeader.tickCount = rawFileData.tickCount;
  iExposedFileHeader.tickRate = rawFileData.tickRate;
  Array_Copy(rawFileData.playerSpawnPos, iExposedFileHeader.playerSpawnPos, 3);
  Array_Copy(rawFileData.playerSpawnAng, iExposedFileHeader.playerSpawnAng, 3);

  
  int iSize = sizeof(BMFileHeader);
  if (numParams > 2)
    iSize = GetNativeCell(3);
  if (iSize > sizeof(BMFileHeader))
    iSize = sizeof(BMFileHeader);

  SetNativeArray(2, iExposedFileHeader, iSize);
  return view_as<int>(BM_NoError);
}

public int Native_ChangeBotNameFromFile(Handle plugin, int numParams) {
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

  S_FileData rawFileData;
  if (!g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData))) {
    BMError error = LoadRecordFromFile(sPath, sCategory, rawFileData, false, false);
    if (error != BM_NoError)
      return view_as<int>(error);
  }

  // Load the whole record first or we'd lose the frames!
  if (rawFileData.frames == null)
    LoadRecordFromFile(sPath, sCategory, rawFileData, false, true);

  GetNativeStringLength(2, iLen);
  char[] sName = new char[iLen+1];
  GetNativeString(2, sName, iLen+1);

  strcopy(rawFileData.playerName, MAX_RECORD_NAME_LENGTH, sName);
  g_hLoadedRecords.SetArray(sPath, rawFileData, sizeof(rawFileData));

  WriteRecordToDisk(sPath, rawFileData);

  return view_as<int>(BM_NoError);
}

public int Native_GetGameMode(Handle plugin, int numParams) {
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

public int Native_GetVersusModeReactionTime(Handle plugin, int numParams) {
  bool change = GetNativeCell(1);
  if (change) {
    g_VersusMode_ReactTime += 30;
    g_VersusMode_ReactTime = (g_VersusMode_ReactTime > VersusMode_ReactTimeMAX)
      ? VersusMode_ReactTimeMIN
      : g_VersusMode_ReactTime;
  }
  return g_VersusMode_ReactTime;
}

public int Native_GetVersusModeMoveDistance(Handle plugin, int numParams) {
  bool change = GetNativeCell(1);
  if (change) {
    g_VersusMode_MoveDistance += 30;
    g_VersusMode_MoveDistance = (g_VersusMode_MoveDistance > VersusMode_MoveDistanceMAX)
      ? VersusMode_MoveDistanceMIN
      : g_VersusMode_MoveDistance;
  }
  return g_VersusMode_MoveDistance;
}

public int Native_GetLoadedRecordList(Handle plugin, int numParams) {
  return view_as<int>(g_hSortedRecordList);
}

public int Native_GetLoadedRecordCategoryList(Handle plugin, int numParams) {
  return view_as<int>(g_hSortedCategoryList);
}

public int Native_GetFileCategory(Handle plugin, int numParams) {
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