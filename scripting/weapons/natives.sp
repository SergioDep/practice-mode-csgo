public int Weapons_GetClientKnife_Native(Handle plugin, int numparams)
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
	char KnifeName[64];
	GetClientKnife(client, KnifeName, sizeof(KnifeName));
	SetNativeString(2, KnifeName, GetNativeCell(3));
	return 0;
}

public int Weapons_SetClientKnife_Native(Handle plugin, int numparams)
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
	char KnifeName[64];
	GetNativeString(2, KnifeName, 64);
	bool update = !!GetNativeCell(3);
	SetClientKnife(client, KnifeName, true, update);
	return 0;
}

public int Weapons_CopyClientProps_Native(Handle plugin, int numParams) {
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
	g_iSkins[client] = g_iSkins[target];
	g_iStatTrak[client] = g_iStatTrak[target];
	g_iStatTrakCount[client] = g_iStatTrakCount[target];
	g_iWeaponSeed[client] = g_iWeaponSeed[target];
	for (int k = 0; k < sizeof(g_WeaponClasses); k++)
	{
		g_NameTag[client][k] = g_NameTag[target][k];
	}
	g_fFloatValue[client] = g_fFloatValue[target];
	g_iEquipTempKnife[client] = g_iEquipTempKnife[target];
	g_iIndex[client] = g_iIndex[target];
	g_FloatTimer[client] = g_FloatTimer[target];
	g_bWaitingForNametag[client] = g_bWaitingForNametag[target];
	g_bWaitingForSeed[client] = g_bWaitingForSeed[target];
	g_iSeedRandom[client] = g_iSeedRandom[target];
	g_iKnife[client] = g_iKnife[target];
	g_iClientLanguage[client] = g_iClientLanguage[target];
	return 0;
}
