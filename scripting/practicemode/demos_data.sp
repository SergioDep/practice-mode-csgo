
public int GetDemosNextId() {
  int largest = -1;
  char id[DEMO_ID_LENGTH];
  if (g_DemosKv.GotoFirstSubKey()) {
    do {
      g_DemosKv.GetSectionName(id, sizeof(id));
      int idvalue = StringToInt(id);
      if (idvalue > largest) {
        largest = idvalue;
      }
    } while (g_DemosKv.GotoNextKey());
    g_DemosKv.GoBack();
  }
  return largest + 1;
}

public void SetDemoName(const char[] id, const char[] newName) {
  g_UpdatedDemoKv = true;
  if (g_DemosKv.JumpToKey(id, true)) {
    g_DemosKv.SetString("name", newName);
    g_DemosKv.GoBack();
  }
  MaybeWriteNewDemoData();
}

public void GetDemoName(const char[] id, char[] buffer, int length) {
  if (g_DemosKv.JumpToKey(id)) {
    g_DemosKv.GetString("name", buffer, length);
    g_DemosKv.GoBack();
  }
}

public void DeleteDemo(const char[] demoId) {
  if (g_DemosKv.JumpToKey(demoId)) {
    g_UpdatedDemoKv = true;
    g_DemosKv.DeleteThis();
    g_DemosKv.Rewind();
  }
  MaybeWriteNewDemoData();
}

public void DeleteDemoRole(const char[] demoId, const char[] roleId) {
  if (g_DemosKv.JumpToKey(demoId)) {
    if (g_DemosKv.JumpToKey(roleId)) {
      g_UpdatedDemoKv = true;
      g_DemosKv.DeleteThis();
    }
  }
  g_DemosKv.Rewind();
}

public void MaybeWriteNewDemoData() {
  if (g_UpdatedDemoKv) {
    g_DemosKv.Rewind();
    BackupFiles("demos");
    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    char demoFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, demoFile, sizeof(demoFile), "data/practicemode/demos/%s.cfg", map);
    DeleteFile(demoFile);
    if (!g_DemosKv.ExportToFile(demoFile)) {
      PrintToServer("[MaybeWriteNewDemoData]Failed to write demos to %s", demoFile);
    }
    g_UpdatedDemoKv = false;
  }
}

public bool GetDemoRoleKVString(const char[] demoId, const char[] roleId, const char[] key, char[] buffer, int size) {
  bool success = false;
  if (g_DemosKv.JumpToKey(demoId)) {
    if (g_DemosKv.JumpToKey(roleId)) {
      g_DemosKv.GetString(key, buffer, size);
      success = !StrEqual(buffer, "");
      g_DemosKv.GoBack();
    }
    g_DemosKv.GoBack();
  }
  return success;
}

public bool SetDemoRoleKVString(const char[] demoId, const char[] roleId, const char[] key, const char[] value) {
  g_UpdatedDemoKv = true;
  bool ret = false;
  if (g_DemosKv.JumpToKey(demoId, true)) {
    if (g_DemosKv.JumpToKey(roleId, true)) {
      ret = true;
      g_DemosKv.SetString(key, value);
      g_DemosKv.GoBack();
    }
    g_DemosKv.GoBack();
  }
  return ret;
}

public void GetDemoRoleKVNades(int client, const char[] demoId, const char[] roleId) {
  g_DemoNadeData[client].Clear();
  if (g_DemosKv.JumpToKey(demoId)) { // , true
    if (g_DemosKv.JumpToKey(roleId)) { // , true
      if (g_DemosKv.JumpToKey("nades")) { // , true
        if (g_DemosKv.GotoFirstSubKey()) {
          do {
            DemoNadeData demoNadeData;
            g_DemosKv.GetVector("origin", demoNadeData.origin);
            g_DemosKv.GetVector("angles", demoNadeData.angles);
            g_DemosKv.GetVector("grenadeOrigin", demoNadeData.grenadeOrigin);
            g_DemosKv.GetVector("grenadeVelocity", demoNadeData.grenadeVelocity);

            char typeString[GRENADE_NAME_LENGTH];
            g_DemosKv.GetString("grenadeType", typeString, sizeof(typeString));
            demoNadeData.grenadeType = GrenadeTypeFromString(typeString);
            demoNadeData.delay = g_DemosKv.GetFloat("delay");
            g_DemoNadeData[client].PushArray(demoNadeData, sizeof(demoNadeData));
          } while (g_DemosKv.GotoNextKey());
        }
      }
    }
  }
  g_DemosKv.Rewind();
}

public void SetDemoRoleKVNades(int client, const char[] demoId, const char[] roleId) {
  g_UpdatedDemoKv = true;
  if (g_DemosKv.JumpToKey(demoId, true)) {
    if (g_DemosKv.JumpToKey(roleId, true)) {
      if (g_DemosKv.JumpToKey("nades", true)) {
        for (int i = 0; i < g_DemoNadeData[client].Length; i++) {
          char nadeIdStr[DEMO_ID_LENGTH];
          IntToString(i, nadeIdStr, sizeof(nadeIdStr));
          if (g_DemosKv.JumpToKey(nadeIdStr, true)){
            DemoNadeData demoNadeData;
            g_DemoNadeData[client].GetArray(i, demoNadeData, sizeof(demoNadeData));
            
            char grenadeTypeStr[GRENADE_NAME_LENGTH];
            GrenadeTypeString(demoNadeData.grenadeType, grenadeTypeStr, sizeof(grenadeTypeStr));
            g_DemosKv.SetVector("origin", demoNadeData.origin);
            g_DemosKv.SetVector("angles", demoNadeData.angles);
            g_DemosKv.SetVector("grenadeOrigin", demoNadeData.grenadeOrigin);
            g_DemosKv.SetVector("grenadeVelocity", demoNadeData.grenadeVelocity);
            g_DemosKv.SetString("grenadeType", grenadeTypeStr);
            g_DemosKv.SetFloat("delay", demoNadeData.delay);
            g_DemosKv.GoBack();
          }
        }
      }
    }
  }
  g_DemosKv.Rewind();
}

public bool CheckDemoRoleKVString(const char[] demoId, int roleId, const char[] key) {
  char buffer[PLATFORM_MAX_PATH];
  char roleIdStr[DEMO_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  return GetDemoRoleKVString(demoId, roleIdStr, key, buffer, sizeof(buffer));
}

public bool DemoExists(const char[] demoId) {
  if (StrEqual(demoId, "")) {
    return false;
  }

  bool ret = false;
  if (g_DemosKv.JumpToKey(demoId)) {
    ret = true;
    g_DemosKv.GoBack();
  }
  return ret;
}
