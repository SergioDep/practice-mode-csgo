//////"[PTaH] Block SM Plugins", author = "Bara"//////
#include <PTaH>

ConVar g_cBlockPlugins = null;
ConVar g_cBlockSM = null;

char g_sLogs[PLATFORM_MAX_PATH + 1];

public void CommandsBlocker_PluginStart() {
  g_cBlockPlugins = CreateConVar("sbp_block_plugins", "1", "Block 'sm plugins'?", _, true, 0.0, true, 1.0);
  g_cBlockSM = CreateConVar("sbp_block_sm", "1", "Block 'sm'?", _, true, 0.0, true, 1.0);

  PTaH(PTaH_ConsolePrintPre, Hook, ConsolePrint);
  PTaH(PTaH_ExecuteStringCommandPre, Hook, ExecuteStringCommand);

  char sDate[18];
  FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
  BuildPath(Path_SM, g_sLogs, sizeof(g_sLogs), "logs/sbp-%s.log", sDate);
}

public Action ConsolePrint(int client, char message[1024]) {
  if (IsClientConnected(client)) {    
    if(g_cBlockPlugins.BoolValue) {
      if(StrContains(message, ".smx\" ") != -1) {
        return Plugin_Handled;
      }
      else if(StrContains(message, "To see more, type \"sm ", false) != -1) {
        LogToFile(g_sLogs, "\"%L\" tried to get -> %s", client, message);
        return Plugin_Handled;
      }
    }
  }
  return Plugin_Continue;
}

public Action ExecuteStringCommand(int client, char sCommandString[512]) {
  if (IsPlayer(client)) {
    char message[512];
    strcopy(message, sizeof(message), sCommandString);
    TrimString(message);

    if(g_cBlockSM.BoolValue && StrContains(message, "sm ") == 0 || StrEqual(message, "sm", false)) {
      LogToFile(g_sLogs, "\"%L\" failed to use %s.", client, message);
      return Plugin_Handled;
    }
  }
  return Plugin_Continue; 
}
