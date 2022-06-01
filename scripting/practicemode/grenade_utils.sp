/**
 * Some generic helpers functions.
 */

public bool IsGrenadeProjectile(const char[] className) {
  static char projectileTypes[][] = {
      "hegrenade_projectile", "smokegrenade_projectile", "decoy_projectile",
      "flashbang_projectile", "molotov_projectile",
  };

  return FindStringInArray2(projectileTypes, sizeof(projectileTypes), className) >= 0;
}

public bool IsGrenadeWeapon(const char[] weapon) {
  static char grenades[][] = {
      "weapon_incgrenade", "weapon_molotov",   "weapon_hegrenade",
      "weapon_decoy",      "weapon_flashbang", "weapon_smokegrenade",
  };

  return FindStringInArray2(grenades, sizeof(grenades), weapon) >= 0;
}

stock void TeleportToGrenadeHistoryPosition(int client, int index,
                                            MoveType moveType = MOVETYPE_WALK) {
  float origin[3];
  float angles[3];
  float velocity[3];
  g_GrenadeHistoryPositions[client].GetArray(index, origin, sizeof(origin));
  g_GrenadeHistoryAngles[client].GetArray(index, angles, sizeof(angles));
  TeleportEntity(client, origin, angles, velocity);
  SetEntityMoveType(client, moveType);
}

public bool FindId(const char[] idStr, char[] auth, int authLen) {
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) { 
    do {
      g_GrenadeLocationsKv.GetSectionName(auth, authLen);
      // Inner iteration by grenades for a user.
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          char currentId[GRENADE_ID_LENGTH];
          g_GrenadeLocationsKv.GetSectionName(currentId, sizeof(currentId));
          if (StrEqual(idStr, currentId)) {
            g_GrenadeLocationsKv.Rewind();
            return true;
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  } 

  return false;
}

public bool TryJumpToId(const char[] idStr) {
  char auth[AUTH_LENGTH];
  if (FindId(idStr, auth, sizeof(auth))) {
    g_GrenadeLocationsKv.JumpToKey(auth, true);
    g_GrenadeLocationsKv.JumpToKey(idStr, true);
    return true;
  }

  return false;
}

public bool TryJumpToOwnerId(const char[] idStr, char[] ownerAuth, int authLength, char[] ownerName,
                      int nameLength) {
  if (FindId(idStr, ownerAuth, authLength)) {
    g_GrenadeLocationsKv.JumpToKey(ownerAuth, true);
    g_GrenadeLocationsKv.GetString("name", ownerName, nameLength);
    g_GrenadeLocationsKv.JumpToKey(idStr, true);
    return true;
  }

  return false;
}

public bool TeleportToSavedGrenadePosition(int client, const char[] id) {
  float origin[3];
  float angles[3];
  float velocity[3];
  char execution[GRENADE_EXECUTION_LENGTH];
  bool success = false;
  float delay = 0.0;
  char typeString[32];
  GrenadeType type = GrenadeType_None;

  // Update the client's current grenade id.
  g_CurrentSavedGrenadeId[client] = StringToInt(id);

  char targetAuth[AUTH_LENGTH];
  char targetName[MAX_NAME_LENGTH];
  if (TryJumpToOwnerId(id, targetAuth, sizeof(targetAuth), targetName, sizeof(targetName))) {
    char grenadeName[GRENADE_NAME_LENGTH];
    success = true;
    g_GrenadeLocationsKv.GetVector("origin", origin);
    g_GrenadeLocationsKv.GetVector("angles", angles);
    g_GrenadeLocationsKv.GetString("name", grenadeName, sizeof(grenadeName));
    g_GrenadeLocationsKv.GetString("execution", execution, sizeof(execution));
    g_GrenadeLocationsKv.GetString("grenadeType", typeString, sizeof(typeString));
    type = GrenadeTypeFromString(typeString);
    delay = g_GrenadeLocationsKv.GetFloat("delay");
    TeleportEntity(client, origin, angles, velocity);
    SetEntityMoveType(client, MOVETYPE_WALK);
    
    if (!StrEqual(execution, "")) {
      //PM_Message(client, "Ejecución: %s", execution);
      SetHudTextParams(-1.0, 0.67, 3.5, 64, 255, 64, 0, 1, 1.0, 1.0, 1.0);
      ShowSyncHudText(client, HudSync, execution);
    }

    if (delay > 0.0) {
      // PM_Message(client, "Delay de granada: %.1f seconds", delay);
    }

    if (type != GrenadeType_None) {
      char weaponName[64];
      GetGrenadeWeapon(type, weaponName, sizeof(weaponName));
      FakeClientCommand(client, "use %s", weaponName);

      // This is a dirty hack since saved nade data doesn't differentiate between a inc and molotov
      // grenade. See the problem in GrenadeFromProjectileName in csutils.inc. If that is fixed this
      // can be removed.
      if (type == GrenadeType_Molotov) {
        FakeClientCommand(client, "use weapon_incgrenade");
      } else if (type == GrenadeType_Incendiary) {
        FakeClientCommand(client, "use weapon_molotov");
      }
    }

    g_GrenadeLocationsKv.Rewind();
  }

  return success;
}

stock bool ThrowGrenade(int client, const char[] id, float delay = 0.0) {
  if (!g_CSUtilsLoaded) {
    return false;
  }

  char typeString[32];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  bool success = false;

  char auth[AUTH_LENGTH];
  if (!FindId(id, auth, sizeof(auth))) {
    return false;
  }

  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.GetVector("grenadeOrigin", grenadeOrigin);
      g_GrenadeLocationsKv.GetVector("grenadeVelocity", grenadeVelocity);
      g_GrenadeLocationsKv.GetString("grenadeType", typeString, sizeof(typeString));
      GrenadeType type = GrenadeTypeFromString(typeString);
      if (IsGrenade(type)) {
        success = true;
        if (delay > 0.1) {
          CSU_DelayThrowGrenade(delay, 0, type, grenadeOrigin, grenadeVelocity);
        } else {
          CSU_ThrowGrenade(client, type, grenadeOrigin, grenadeVelocity);
        }
      }
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }

  return success;
}

stock int SaveGrenadeToKv(int client, const float origin[3], const float angles[3],
                          const float grenadeOrigin[3], const float grenadeVelocity[3],
                          GrenadeType type, const float grenadeDetonationOrigin[3], 
                          const char[] name, const char[] execution = "") {
  g_UpdatedGrenadeKv = true;
  char idStr[GRENADE_ID_LENGTH];
  IntToString(g_NextID, idStr, sizeof(idStr));

  char auth[AUTH_LENGTH];
  char clientName[MAX_NAME_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  GetClientName(client, clientName, sizeof(clientName));
  g_GrenadeLocationsKv.JumpToKey(auth, true);
  g_GrenadeLocationsKv.SetString("name", clientName);

  g_GrenadeLocationsKv.JumpToKey(idStr, true);

  g_GrenadeLocationsKv.SetString("name", name);
  g_GrenadeLocationsKv.SetVector("origin", origin);
  g_GrenadeLocationsKv.SetVector("angles", angles);
  if (g_CSUtilsLoaded && IsGrenade(type)) {
    char grenadeTypeString[32];
    GrenadeTypeString(type, grenadeTypeString, sizeof(grenadeTypeString));
    g_GrenadeLocationsKv.SetString("grenadeType", grenadeTypeString);
    g_GrenadeLocationsKv.SetVector("grenadeOrigin", grenadeOrigin);
    g_GrenadeLocationsKv.SetVector("grenadeVelocity", grenadeVelocity);
    if (grenadeDetonationOrigin[0] || grenadeDetonationOrigin[1] || grenadeDetonationOrigin[2]) {
      g_GrenadeLocationsKv.SetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);
    } else {
      // Try Predict Ending Pos
      float predictedEndPos[3];
      char weaponName[128];
      GetGrenadeWeapon(type, weaponName, sizeof(weaponName));
      bool predictJumpThrow = view_as<bool>(StrContains(execution, "Jump", false) + 1);
      CreateTrajectory(client, weaponName, predictJumpThrow, GetEntityFlags(client) & FL_DUCKING, predictedEndPos, origin, angles);
      g_GrenadeLocationsKv.SetVector("grenadeDetonationOrigin", predictedEndPos);
    }
    g_GrenadeLocationsKv.SetString("execution", execution);
    char toEncrypt[512];
    Format(toEncrypt, sizeof(toEncrypt), "O%f%f%fGV%f%f%f",
      origin[0], origin[1], origin[2],
      grenadeVelocity[0], grenadeVelocity[1], grenadeVelocity[2]);
    char code[GRENADE_CODE_LENGTH];
    Crypt_MD5(toEncrypt, code, sizeof(code));
    g_GrenadeLocationsKv.SetString("code", code);
  }

  g_GrenadeLocationsKv.GoBack();
  g_GrenadeLocationsKv.GoBack();
  g_NextID++;

  return g_NextID - 1;
}

public bool DeleteGrenadeFromKv(const char[] nadeIdStr) {
  g_UpdatedGrenadeKv = true;
  char auth[AUTH_LENGTH];
  FindId(nadeIdStr, auth, sizeof(auth));
  bool deleted = false;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    char name[GRENADE_NAME_LENGTH];
    if (g_GrenadeLocationsKv.JumpToKey(nadeIdStr)) {
      g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
      g_GrenadeLocationsKv.GoBack();
    }

    deleted = g_GrenadeLocationsKv.DeleteKey(nadeIdStr);
    g_GrenadeLocationsKv.GoBack();
  }

  // If the grenade deleted has the highest grenadeId, reset nextid to it so that
  // we don't waste spots in the greandeId-space.
  if (deleted) {
    if (StringToInt(nadeIdStr) + 1 == g_NextID) {
      g_NextID--;
    }
  }
  
  return deleted;
}

public void AddGrenadeToHistory(int client) {
  int max_grenades = g_MaxHistorySizeCvar.IntValue;
  if (max_grenades > 0 && GetArraySize(g_GrenadeHistoryPositions[client]) >= max_grenades) {
    RemoveFromArray(g_GrenadeHistoryPositions[client], 0);
    RemoveFromArray(g_GrenadeHistoryAngles[client], 0);
  }
  
  PushArrayArray(g_GrenadeHistoryPositions[client], g_LastGrenadePinPulledOrigin[client], sizeof(g_LastGrenadePinPulledOrigin[]));
  PushArrayArray(g_GrenadeHistoryAngles[client], g_LastGrenadePinPulledAngles[client], sizeof(g_LastGrenadePinPulledAngles[]));
  //when grenade released, but instead if when grenade pin pulled so it allows runthrows
  g_GrenadeHistoryIndex[client] = g_GrenadeHistoryPositions[client].Length;
}

public void SetGrenadeData(const char[] auth, const char[] id, const char[] key, const char[] value) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetString(key, value);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void SetGrenadeFloat(const char[] auth, const char[] id, const char[] key, float value) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetFloat(key, value);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void GetGrenadeData(const char[] auth, const char[] id, const char[] key, char[] value,
                    int valueLength) {
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.GetString(key, value, valueLength);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public float GetGrenadeFloat(const char[] auth, const char[] id, const char[] key) {
  float value = 0.0;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      value = g_GrenadeLocationsKv.GetFloat(key);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return value;
}

public void GetGrenadeVector(const char[] auth, const char[] id, const char[] key, float vector[3]) {
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.GetVector(key, vector);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void SetGrenadeVector(const char[] auth, const char[] id, const char[] key, const float vector[3]) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetVector(key, vector);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void SetClientGrenadeData(int id, const char[] key, const char[] value) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  SetGrenadeData(auth, nadeId, key, value);
}

public void GetClientGrenadeData(int id, const char[] key, char[] value, int valueLength) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  GetGrenadeData(auth, nadeId, key, value, valueLength);
}

public void SetClientGrenadeFloat(int id, const char[] key, float value) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  SetGrenadeFloat(auth, nadeId, key, value);
}

public float GetClientGrenadeFloat(int id, const char[] key) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  return GetGrenadeFloat(auth, nadeId, key);
}

public void GetClientGrenadeVector(int id, const char[] key, float vector[3]) {
  char auth[AUTH_LENGTH];
  char nadeId[GRENADE_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  GetGrenadeVector(auth, nadeId, key, vector);
}

stock int CountGrenadesForPlayer(const char[] auth, GrenadeType grenadeType = GrenadeType_None) {
  int count = 0;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        if (grenadeType == GrenadeType_None) {
          count++;
        } else {
          char grenadeTypeString[32];
          g_GrenadeLocationsKv.GetString("grenadeType", grenadeTypeString, sizeof(grenadeTypeString));
          if (grenadeType == GrenadeTypeFromString(grenadeTypeString)) {
            count++;
          }
        }
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return count;
}

// public int FindNextGrenadeId(int client, int currentId) {
//   char auth[AUTH_LENGTH];
//   GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

//   int ret = -1;
//   if (g_GrenadeLocationsKv.JumpToKey(auth)) {
//     if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
//       do {
//         char idBuffer[GRENADE_ID_LENGTH];
//         g_GrenadeLocationsKv.GetSectionName(idBuffer, sizeof(idBuffer));
//         int id = StringToInt(idBuffer);
//         if (id > currentId) {
//           ret = id;
//           break;
//         }
//       } while (g_GrenadeLocationsKv.GotoNextKey());
//       g_GrenadeLocationsKv.GoBack();
//     }
//     g_GrenadeLocationsKv.GoBack();
//   }

//   return ret;
// }

static KeyValues g_NewKv;

static ArrayList g_AllIds;
static bool g_RepeatIdSeen;

public void MaybeCorrectGrenadeIds() {
  // Determine if we need to do this first. Iterate over all grenades and store the ids as an int.
  // If we see a repeat, then we need to do the correction.
  g_AllIds = new ArrayList();
  g_RepeatIdSeen = false;
  IterateGrenades(IsCorrectionNeededHelper);

  // But first... let's make sure the nextid field is always right.
  SortADTArray(g_AllIds, Sort_Ascending, Sort_Integer);
  int biggestID = 0;
  if (g_AllIds.Length > 0) {
    biggestID = g_AllIds.Get(g_AllIds.Length - 1);
  }
  g_NextID = biggestID + 1;

  delete g_AllIds;

  if (g_RepeatIdSeen) {
    CorrectGrenadeIds();
  }
}

public Action IsCorrectionNeededHelper(
  const char[] ownerName, 
  const char[] ownerAuth, 
  const char[] name,
  const char[] execution, 
  const char[] grenadeId, 
  const float origin[3], 
  const float angles[3],
  const char[] grenadeType, 
  const float grenadeOrigin[3], 
  const float grenadeVelocity[3], 
  const float grenadeDetonationOrigin[3], 
  any data
) {
  int id = StringToInt(grenadeId);
  if (g_AllIds.FindValue(id) >= 0) {
    g_RepeatIdSeen = true;
  }
  g_AllIds.Push(id);
  return Plugin_Continue;
}

public void CorrectGrenadeIds() {
  // We'll do the correction; use a temp kv structure to copy data over using new ids and
  // swap it into the existing g_GrenadeLocationsKv structure.
  PrintToServer("Updating grenadeIds since duplicates were found...");
  g_NewKv = new KeyValues("Grenades");
  g_NextID = 1;
  IterateGrenades(CorrectGrenadeIdsHelper);

  // Move the temp g_NewKv to replace data in g_GrenadeLocationsKv.
  delete g_GrenadeLocationsKv;
  g_GrenadeLocationsKv = g_NewKv;
  g_NewKv = null;
  g_UpdatedGrenadeKv = true;
}

public Action CorrectGrenadeIdsHelper(
  const char[] ownerName, 
  const char[] ownerAuth, 
  const char[] name, 
  const char[] execution, 
  const char[] grenadeId, 
  const float origin[3], 
  const float angles[3], 
  const char[] grenadeType, 
  const float grenadeOrigin[3], 
  const float grenadeVelocity[3], 
  const float grenadeDetonationOrigin[3], 
  any data
) {
  char newId[64];
  IntToString(g_NextID, newId, sizeof(newId));
  g_NextID++;

  if (g_NewKv.JumpToKey(ownerAuth, true)) {
    g_NewKv.SetString("name", ownerName);
    if (g_NewKv.JumpToKey(newId, true)) {
      g_NewKv.SetString("name", name);
      g_NewKv.SetVector("origin", origin);
      g_NewKv.SetVector("angles", angles);
      g_NewKv.SetString("execution", execution);
      g_NewKv.GoBack();
    }
  }
  g_NewKv.Rewind();
  return Plugin_Continue;
}

public bool CanEditGrenade(int client, int id) {
  bool ret = false;
  char clientAuth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
  if (g_GrenadeLocationsKv.JumpToKey(clientAuth)) {
    char strId[32];
    IntToString(id, strId, sizeof(strId));
    if (g_GrenadeLocationsKv.JumpToKey(strId)) {
      ret = true;
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return ret;
}

public void GetGrenadeExecutionType(int btns, char[] buffer, int size) {
  bool printSeparator = false;
  char execution[GRENADE_EXECUTION_LENGTH-1];
  if (btns & IN_SPEED) {
    strcopy(execution, sizeof(execution), "Shift");
    printSeparator = true;
  }
  if (btns & IN_DUCK) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "CTRL");
    printSeparator = true;
  }
  if (btns & IN_FORWARD) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "W");
    printSeparator = true;
  }
  if (btns & IN_MOVELEFT) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "A");
    printSeparator = true;
  }
  if (btns & IN_MOVERIGHT) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "D");
    printSeparator = true;
  }
  if (btns & IN_BACK) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "S");
    printSeparator = true;
  }
  if (btns & IN_ATTACK) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "Mouse1");
    printSeparator = true;
  }
  if (btns & IN_ATTACK2) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "Mouse2");
    printSeparator = true;
  }
  if (btns & IN_JUMP) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "JumpThrow");
  }

  strcopy(buffer, size, execution);
}

public int CopyGrenade(int client, const char[] nadeId) {
  float origin[3];
  float angles[3];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  float grenadeDetonationOrigin[3];
  char grenadeTypeString[32];
  char grenadeName[GRENADE_NAME_LENGTH];
  char execution[GRENADE_EXECUTION_LENGTH];

  if (TryJumpToId(nadeId)) {
    g_GrenadeLocationsKv.GetString("name", grenadeName, sizeof(grenadeName));
    g_GrenadeLocationsKv.GetVector("origin", origin);
    g_GrenadeLocationsKv.GetVector("angles", angles);
    g_GrenadeLocationsKv.GetString("grenadeType", grenadeTypeString, sizeof(grenadeTypeString));
    g_GrenadeLocationsKv.GetVector("grenadeOrigin", grenadeOrigin);
    g_GrenadeLocationsKv.GetVector("grenadeVelocity", grenadeVelocity);
    g_GrenadeLocationsKv.GetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);
    g_GrenadeLocationsKv.GetString("execution", execution, sizeof(execution));
    g_GrenadeLocationsKv.Rewind();
    return SaveGrenadeToKv(client, origin, angles, grenadeOrigin, grenadeVelocity,
                           GrenadeTypeFromString(grenadeTypeString),
                           grenadeDetonationOrigin, grenadeName, execution);
  }
  return -1;
}

public void ExportClientNade(int client, const char[] idstr) {
  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  char code[GRENADE_CODE_LENGTH];
  GetGrenadeData(auth, idstr, "code", code, sizeof(code));
  PM_Message(client, "{ORANGE}Codigo Exportado! (usar .import para guardarlo)");
  PM_Message(client, "{GREEN}%s", code);
  PrintToConsole(client, "======================================================");
  PrintToConsole(client, "Codigo de Granada Exportado : %s", code);
  PrintToConsole(client, "======================================================");
}

public void SaveClientNade(int client, const char[] name) {
  if (StrEqual(name, "")) {
    PM_Message(client, "Uso: .save <nombre>");
    return;
  }

  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  char grenadeId[GRENADE_ID_LENGTH];
  if (FindGrenadeByName(auth, name, grenadeId)) {
    PM_Message(client, "Ya has usado ese nombre.");
    return;
  }

  int max_saved_grenades = MAX_GRENADE_SAVES_PLAYER;
  if (max_saved_grenades > 0 && CountGrenadesForPlayer(auth) >= max_saved_grenades) {
    PM_Message(client, "Alcanzaste el maximo numero de granadas que puedes guardar (%d).",
               max_saved_grenades);
    return;
  }

  float origin[3], angles[3];
  origin = g_LastGrenadePinPulledOrigin[client];
  angles = g_LastGrenadePinPulledAngles[client];

  GrenadeType grenadeType = g_LastGrenadeType[client];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  float grenadeDetonationOrigin[3];
  grenadeOrigin = g_LastGrenadeOrigin[client];
  grenadeVelocity = g_LastGrenadeVelocity[client];
  grenadeDetonationOrigin = g_LastGrenadeDetonationOrigin[client];

  char execution[GRENADE_EXECUTION_LENGTH];
  GetGrenadeExecutionType(g_ClientPulledPinButtons[client], execution, sizeof(execution));

  Action ret = Plugin_Continue;
  Call_StartForward(g_OnGrenadeSaved);
  Call_PushCell(client);
  Call_PushArray(origin, sizeof(origin));
  Call_PushArray(angles, sizeof(angles));
  Call_PushString(name);
  Call_Finish(ret);

  if (ret < Plugin_Handled) {
    if (g_CSUtilsLoaded) {
      if (!IsGrenade(g_LastGrenadeType[client])) {
        PM_Message(client, "{DARK_RED}Error. Guarda una granada válida");
        return;
      } else {
        int nadeId = SaveGrenadeToKv(client, origin, angles,
          grenadeOrigin, grenadeVelocity, grenadeType, grenadeDetonationOrigin,
          name, execution
        );
        g_CurrentSavedGrenadeId[client] = nadeId;
        int authIndex = g_EnabledHoloNadeAuth.FindString(auth);
        if(authIndex == -1) {
          g_EnabledHoloNadeAuth.PushString(auth);
        }
        PM_Message(client, "{ORANGE}Granada {PURPLE}%s {ORANGE}guardada.", name);
        g_UpdatedGrenadeKv = true;
        MaybeWriteNewGrenadeData();
        OnGrenadeKvMutate();
        if (!g_InBotDemoMode && g_recordingNadeDemoStatus[client] > 0) { //1 or 2
          g_recordingNadeDemoStatus[client] = 0;
          g_savedNewNadeDemo[client] = true;
          if (BotMimic_IsPlayerRecording(client)) {
            BotMimic_StopRecording(client, true);
          }
        }
    }
    }
  }
  g_LastGrenadeType[client] = GrenadeType_None;
}
