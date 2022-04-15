
public int GetRetakesNextId() {
  int largest = -1;
  char id[RETAKE_ID_LENGTH];
  if (g_RetakesKv.GotoFirstSubKey()) {
    do {
      g_RetakesKv.GetSectionName(id, sizeof(id));
      int idvalue = StringToInt(id);
      if (idvalue > largest) {
        largest = idvalue;
      }
    } while (g_RetakesKv.GotoNextKey());
    g_RetakesKv.GoBack();
  }
  return largest + 1;
}

public void SetRetakeName(const char[] id, const char[] newName) {
  g_UpdatedRetakeKv = true;
  if (g_RetakesKv.JumpToKey(id, true)) {
    g_RetakesKv.SetString("name", newName);
    g_RetakesKv.GoBack();
  }
  MaybeWriteNewRetakeData();
}

public void GetRetakeName(const char[] id, char[] buffer, int length) {
  if (g_RetakesKv.JumpToKey(id)) {
    g_RetakesKv.GetString("name", buffer, length);
    g_RetakesKv.GoBack();
  }
}

public void DeleteRetake(const char[] id) {
  if (g_RetakesKv.JumpToKey(id)) {
    g_UpdatedRetakeKv = true;
    g_RetakesKv.DeleteThis();
    g_RetakesKv.Rewind();
  }
  MaybeWriteNewRetakeData();
}

public void DeleteRetakeSpawn(const char[] retakeid, const char[] spawnType, const char[] spawnid) {
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.JumpToKey(spawnid)) {
        g_UpdatedRetakeKv = true;
        g_RetakesKv.DeleteThis();
      }
    }
  }
  g_RetakesKv.Rewind();
  MaybeWriteNewRetakeData();
}

public void GetRetakeSpawnsNextId(const char[] retakeid, const char[] spawnType, char[] buffer, int size) {
  int largest = -1;
  char id[RETAKE_ID_LENGTH];
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.GotoFirstSubKey()) {
        do {
          g_RetakesKv.GetSectionName(id, sizeof(id));
          int idvalue = StringToInt(id);
          if (idvalue > largest) {
            largest = idvalue;
          }
        } while (g_RetakesKv.GotoNextKey());
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  IntToString(largest + 1, buffer, size);
}

public bool SetRetakeSpawnVectorKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, const float value[3]) {
  g_UpdatedRetakeKv = true;
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid, true)) {
    if (g_RetakesKv.JumpToKey(spawnType, true)) {
      if (g_RetakesKv.JumpToKey(spawnid, true)) {
        ret = true;
        g_RetakesKv.SetVector(key, value);
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  MaybeWriteNewRetakeData();
  return ret;
}

public bool GetRetakeSpawnVectorKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, float value[3]) {
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.JumpToKey(spawnid)) {
        g_RetakesKv.GetVector(key, value);
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  return ret;
}

public bool GetRetakeSpawnStringKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, char[] buffer, int size) {
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.JumpToKey(spawnid)) {
        g_RetakesKv.GetString(key, buffer, size);
        ret = true;
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  return ret;
}

public bool SetRetakeSpawnStringKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, const char[] value) {
  g_UpdatedRetakeKv = true;
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid, true)) {
    if (g_RetakesKv.JumpToKey(spawnType, true)) {
      if (g_RetakesKv.JumpToKey(spawnid, true)) {
        g_RetakesKv.SetString(key, value);
        ret = true;
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  MaybeWriteNewRetakeData();
  return ret;
}

public void MaybeWriteNewRetakeData() {
  if (g_UpdatedRetakeKv) {
    g_RetakesKv.Rewind();
    BackupFiles("retakes");
    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    char retakeFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, retakeFile, sizeof(retakeFile), "data/practicemode/retakes/%s.cfg", map);
    DeleteFile(retakeFile);
    if (!g_RetakesKv.ExportToFile(retakeFile)) {
      PrintToServer("[RETAKES]Failed to write retakes to %s", retakeFile);
    }
    g_UpdatedRetakeKv = false;
    UpdateHoloRetakeEntities();
  }
}
