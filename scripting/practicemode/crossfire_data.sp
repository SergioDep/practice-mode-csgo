
public int GetCrossfiresNextId() {
  int largest = -1;
  char id[CROSSFIRE_ID_LENGTH];
  if (g_CrossfiresKv.GotoFirstSubKey()) {
    do {
      g_CrossfiresKv.GetSectionName(id, sizeof(id));
      int idvalue = StringToInt(id);
      if (idvalue > largest) {
        largest = idvalue;
      }
    } while (g_CrossfiresKv.GotoNextKey());
    g_CrossfiresKv.GoBack();
  }
  return largest + 1;
}

public void SetCrossfireName(const char[] id, const char[] newName) {
  g_UpdatedCrossfireKv = true;
  if (g_CrossfiresKv.JumpToKey(id, true)) {
    g_CrossfiresKv.SetString("name", newName);
    g_CrossfiresKv.GoBack();
  }
  MaybeWriteNewCrossfireData();
}

public void GetCrossfireName(const char[] id, char[] buffer, int length) {
  if (g_CrossfiresKv.JumpToKey(id)) {
    g_CrossfiresKv.GetString("name", buffer, length);
    g_CrossfiresKv.GoBack();
  }
}

public void DeleteCrossfire(const char[] id) {
  if (g_CrossfiresKv.JumpToKey(id)) {
    g_UpdatedCrossfireKv = true;
    g_CrossfiresKv.DeleteThis();
    g_CrossfiresKv.Rewind();
  }
  MaybeWriteNewCrossfireData();
}

public void DeleteCrossfireSpawn(const char[] crossfireid, const char[] spawnType, const char[] spawnid) {
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.JumpToKey(spawnid)) {
        g_UpdatedCrossfireKv = true;
        g_CrossfiresKv.DeleteThis();
      }
    }
  }
  g_CrossfiresKv.Rewind();
  MaybeWriteNewCrossfireData();
}

public void GetCrossfireSpawnsNextId(const char[] crossfireid, const char[] spawnType, char[] buffer, int size) {
  int largest = -1;
  char id[CROSSFIRE_ID_LENGTH];
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
        do {
          g_CrossfiresKv.GetSectionName(id, sizeof(id));
          int idvalue = StringToInt(id);
          if (idvalue > largest) {
            largest = idvalue;
          }
        } while (g_CrossfiresKv.GotoNextKey());
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  IntToString(largest + 1, buffer, size);
}

public bool SetCrossfireSpawnVectorKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, const float value[3]) {
  g_UpdatedCrossfireKv = true;
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid, true)) {
    if (g_CrossfiresKv.JumpToKey(spawnType, true)) {
      if (g_CrossfiresKv.JumpToKey(spawnid, true)) {
        ret = true;
        g_CrossfiresKv.SetVector(key, value);
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  MaybeWriteNewCrossfireData();
  return ret;
}

public bool GetCrossfireSpawnVectorKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, float value[3]) {
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.JumpToKey(spawnid)) {
        g_CrossfiresKv.GetVector(key, value);
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  return ret;
}

public bool GetCrossfireSpawnStringKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, char[] buffer, int size) {
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.JumpToKey(spawnid)) {
        g_CrossfiresKv.GetString(key, buffer, size);
        ret = true;
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  return ret;
}

public bool SetCrossfireSpawnStringKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, const char[] value) {
  g_UpdatedCrossfireKv = true;
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid, true)) {
    if (g_CrossfiresKv.JumpToKey(spawnType, true)) {
      if (g_CrossfiresKv.JumpToKey(spawnid, true)) {
        g_CrossfiresKv.SetString(key, value);
        ret = true;
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  MaybeWriteNewCrossfireData();
  return ret;
}

public void MaybeWriteNewCrossfireData() {
  if (g_UpdatedCrossfireKv) {
    g_CrossfiresKv.Rewind();
    BackupFiles("crossfires");
    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    char crossfireFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, crossfireFile, sizeof(crossfireFile), "data/practicemode/crossfires/%s.cfg", map);
    DeleteFile(crossfireFile);
    if (!g_CrossfiresKv.ExportToFile(crossfireFile)) {
      PrintToServer("[MaybeWriteNewCrossfireData]Failed to write crossfires to %s", crossfireFile);
    }
    g_UpdatedCrossfireKv = false;
    UpdateHoloCFireEnts();
  }
}
