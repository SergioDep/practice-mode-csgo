/*  CS:GO Gloves SourceMod Plugin
 *
 *  Copyright (C) 2017 Kağan 'kgns' Üstüngel
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Gloves_IsClientUsingGloves", Native_IsClientUsingGloves);
	CreateNative("Gloves_RegisterCustomArms", Native_RegisterCustomArms);
	CreateNative("Gloves_SetArmsModel", Native_SetArmsModel);
	CreateNative("Gloves_GetArmsModel", Native_GetArmsModel);
	CreateNative("Gloves_CopyClientProps", Native_CopyClientProps);
	return APLRes_Success;
}

public int Native_IsClientUsingGloves(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	return g_iGloves[clientIndex][playerTeam] != 0;
}

public int Native_RegisterCustomArms(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	GetNativeString(2, g_CustomArms[clientIndex][playerTeam], 256);
	return 0;
}

public int Native_SetArmsModel(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	GetNativeString(2, g_CustomArms[clientIndex][playerTeam], 256);
	if(g_iGloves[clientIndex][playerTeam] == 0)
	{
		SetEntPropString(clientIndex, Prop_Send, "m_szArmsModel", g_CustomArms[clientIndex][playerTeam]);
	}
	return 0;
}

public int Native_GetArmsModel(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	int size = GetNativeCell(3);
	SetNativeString(2, g_CustomArms[clientIndex][playerTeam], size);
	return 0;
}

public int Native_CopyClientProps(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d).", client);
	}
	if(!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is not in game.", client);
	}
	int target = GetNativeCell(2);
	if (target < 1 || target > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid target index (%d).", target);
	}
	if(!IsClientInGame(target))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Target (%d) is not in game.", target);
	}
	int targetTeam = GetClientTeam(target);
	if (targetTeam == CS_TEAM_T || targetTeam == CS_TEAM_CT) {
		for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++) {
			g_iGroup[client][team] = g_iGroup[target][targetTeam];
			g_iGloves[client][team] = g_iGloves[target][targetTeam];
			g_fFloatValue[client][team] = g_fFloatValue[target][targetTeam];
			g_CustomArms[client][team] = g_CustomArms[target][targetTeam];
		}
	}
	return 0;
}
