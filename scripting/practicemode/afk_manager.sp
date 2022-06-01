// name = "Sammy's Afker Kicker",
// author = "NBK - Sammy-ROCK!",
#define AFK_WARNING_DELAY 10.0

bool AFK_autoCheck;
bool AFK_Warned[MAXPLAYERS + 1] = {false, ...};
float AFK_LastCheckTime[MAXPLAYERS + 1] = {0.0, ...};
float AFK_LastMovementTime[MAXPLAYERS + 1] = {0.0, ...};
float AFK_LastEyeAngle[MAXPLAYERS + 1][3];
float AFK_LastPosition[MAXPLAYERS + 1][3];
Handle AFK_AdminImmune = INVALID_HANDLE;
Handle AFK_TimerDelay = INVALID_HANDLE;
Handle AFK_MaxTime = INVALID_HANDLE;

public AfkManager_PluginStart() {
	AFK_autoCheck = true;
	AFK_AdminImmune= CreateConVar("sammysafkerkicker_adminimmune",	"0", "Should Sammy's Afker Kicker skip admins?", 0, true, 0.0, true, 1.0);
	AFK_TimerDelay = CreateConVar("sammysafkerkicker_check_delay", "300.0", "Delay between checks. How low it is heavier is the plugin.", 0, true, 1.0);
	AFK_MaxTime = CreateConVar("sammysafkerkicker_time_needed", "1200.0", "How long player can stay afk before getting kicked", 0, true, 5.0);
}

public AfkManager_MapStart() {
	CreateTimer(GetConVarFloat(AFK_TimerDelay), CheckAfkUsers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public AfkManager_ClientDisconnect(int client) {
	AFK_Warned[client] = false;
	AFK_LastCheckTime[client] = 0.0;
	AFK_LastMovementTime[client] = 0.0;
}

public Action CheckAfkUsers(Handle timer) {
	if (AFK_autoCheck) {
		float time = GetEngineTime();
		for(int client = 1; client <= MaxClients; client++) {
			if(IsPlayer(client)) {
				float pastTime = time - AFK_LastCheckTime[client];
				if (pastTime > GetConVarFloat(AFK_TimerDelay) - 2.0) {
					AFK_LastCheckTime[client] = time;
					//continue
				} else {
					continue;
				}
				if (GetConVarInt(AFK_AdminImmune) && GetUserFlagBits(client)) {
					continue;
				}
				if (CheckClientIsAfk(client)) {
					if (time - AFK_LastMovementTime[client] >= GetConVarFloat(AFK_MaxTime)) {
						// AFK_LastMovementTime[client] = time;
						KickClient(client, "%t", "AFK_KickReason", GetConVarFloat(AFK_MaxTime)/60);
					} else if (time - AFK_LastMovementTime[client] >= GetConVarFloat(AFK_MaxTime) - AFK_WARNING_DELAY) {
						if (!AFK_Warned[client]) {
							PM_Message(client, "%t", "AFK_Warning", client, view_as<int>(AFK_WARNING_DELAY));
							AFK_Warned[client] = true;
						}
					}
					continue;
				}
				AFK_LastMovementTime[client] = time;
			}
		}
	}
	return Plugin_Continue;
}

stock bool CheckClientIsAfk(int client) {
	float origin[3], angles[3];
	GetClientAbsOrigin(client, origin);
	GetClientEyeAngles(client, angles);
	if (Math_VectorsEqual(origin, AFK_LastPosition[client]) && Math_VectorsEqual(angles, AFK_LastEyeAngle[client])) {
		return true;
	}
	AFK_LastPosition[client] = origin;
	AFK_LastEyeAngle[client] = angles;
	return false;
}
