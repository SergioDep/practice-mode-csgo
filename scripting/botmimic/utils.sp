
// char g_WeaponClasses[][] = {
// /* 0*/ "weapon_awp", /* 1*/ "weapon_ak47", /* 2*/ "weapon_m4a1", /* 3*/ "weapon_m4a1_silencer", /* 4*/ "weapon_deagle", /* 5*/ "weapon_usp_silencer", /* 6*/ "weapon_hkp2000", /* 7*/ "weapon_glock", /* 8*/ "weapon_elite", 
// /* 9*/ "weapon_p250", /*10*/ "weapon_cz75a", /*11*/ "weapon_fiveseven", /*12*/ "weapon_tec9", /*13*/ "weapon_revolver", /*14*/ "weapon_nova", /*15*/ "weapon_xm1014", /*16*/ "weapon_mag7", /*17*/ "weapon_sawedoff", 
// /*18*/ "weapon_m249", /*19*/ "weapon_negev", /*20*/ "weapon_mp9", /*21*/ "weapon_mac10", /*22*/ "weapon_mp7", /*23*/ "weapon_ump45", /*24*/ "weapon_p90", /*25*/ "weapon_bizon", /*26*/ "weapon_famas", /*27*/ "weapon_galilar", 
// /*28*/ "weapon_ssg08", /*29*/ "weapon_aug", /*30*/ "weapon_sg556", /*31*/ "weapon_scar20", /*32*/ "weapon_g3sg1", /*33*/ "weapon_knife_karambit", /*34*/ "weapon_knife_m9_bayonet", /*35*/ "weapon_bayonet", 
// /*36*/ "weapon_knife_survival_bowie", /*37*/ "weapon_knife_butterfly", /*38*/ "weapon_knife_flip", /*39*/ "weapon_knife_push", /*40*/ "weapon_knife_tactical", /*41*/ "weapon_knife_falchion", /*42*/ "weapon_knife_gut",
// /*43*/ "weapon_knife_ursus", /*44*/ "weapon_knife_gypsy_jackknife", /*45*/ "weapon_knife_stiletto", /*46*/ "weapon_knife_widowmaker", /*47*/ "weapon_mp5sd", /*48*/ "weapon_knife_css", /*49*/ "weapon_knife_cord", 
// /*50*/ "weapon_knife_canis", /*51*/ "weapon_knife_outdoor", /*52*/ "weapon_knife_skeleton"
// };

// int g_iWeaponDefIndex[] = {
// /* 0*/ 9, /* 1*/ 7, /* 2*/ 16, /* 3*/ 60, /* 4*/ 1, /* 5*/ 61, /* 6*/ 32, /* 7*/ 4, /* 8*/ 2, 
// /* 9*/ 36, /*10*/ 63, /*11*/ 3, /*12*/ 30, /*13*/ 64, /*14*/ 35, /*15*/ 25, /*16*/ 27, /*17*/ 29, 
// /*18*/ 14, /*19*/ 28, /*20*/ 34, /*21*/ 17, /*22*/ 33, /*23*/ 24, /*24*/ 19, /*25*/ 26, /*26*/ 10, /*27*/ 13, 
// /*28*/ 40, /*29*/ 8, /*30*/ 39, /*31*/ 38, /*32*/ 11, /*33*/ 507, /*34*/ 508, /*35*/ 500, 
// /*36*/ 514, /*37*/ 515, /*38*/ 505, /*39*/ 516, /*40*/ 509, /*41*/ 512, /*42*/ 506,
// /*43*/ 519, /*44*/ 520, /*45*/ 522, /*46*/ 523, /*47*/ 23, /*48*/ 503, /*49*/ 517,
// /*50*/ 518, /*51*/ 521, /*52*/ 525
// };

// CSWeaponID g_CSWeaponIds[] = {
// /* 0*/ CSWeapon_AWP, /* 1*/ CSWeapon_AK47, /* 2*/ CSWeapon_M4A1, /* 3*/ CSWeapon_M4A1_SILENCER, /* 4*/ CSWeapon_DEAGLE, /* 5*/ CSWeapon_USP_SILENCER, /* 6*/ CSWeapon_HKP2000, /* 7*/ CSWeapon_GLOCK, /* 8*/ CSWeapon_ELITE, 
// /* 9*/ CSWeapon_P250, /*10*/ CSWeapon_CZ75A, /*11*/ CSWeapon_FIVESEVEN, /*12*/ CSWeapon_TEC9, /*13*/ CSWeapon_REVOLVER, /*14*/ CSWeapon_NOVA, /*15*/ CSWeapon_XM1014, /*16*/ CSWeapon_MAG7, /*17*/ CSWeapon_SAWEDOFF, 
// /*18*/ CSWeapon_M249, /*19*/ CSWeapon_NEGEV, /*20*/ CSWeapon_MP9, /*21*/ CSWeapon_MAC10, /*22*/ CSWeapon_MP7, /*23*/ CSWeapon_UMP45, /*24*/ CSWeapon_P90, /*25*/ CSWeapon_BIZON, /*26*/ CSWeapon_FAMAS, /*27*/ CSWeapon_GALILAR, 
// /*28*/ CSWeapon_SSG08, /*29*/ CSWeapon_AUG, /*30*/ CSWeapon_SG556, /*31*/ CSWeapon_SCAR20, /*32*/ CSWeapon_G3SG1, /*33*/ CSWeapon_KNIFE_KARAMBIT, /*34*/ CSWeapon_KNIFE_M9_BAYONET, /*35*/ CSWeapon_BAYONET, 
// /*36*/ CSWeapon_KNIFE_SURVIVAL_BOWIE, /*37*/ CSWeapon_KNIFE_BUTTERFLY, /*38*/ CSWeapon_KNIFE_FLIP, /*39*/ CSWeapon_KNIFE_PUSH, /*40*/ CSWeapon_KNIFE_TATICAL, /*41*/ CSWeapon_KNIFE_FALCHION, /*42*/ CSWeapon_KNIFE_GUT,
// /*43*/ CSWeapon_KNIFE_URSUS, /*44*/ CSWeapon_KNIFE_GYPSY_JACKKNIFE, /*45*/ CSWeapon_KNIFE_STILETTO, /*46*/ CSWeapon_KNIFE_WIDOWMAKER, /*47*/ CSWeapon_MP5NAVY, /*48*/ CSWeapon_KNIFE_CLASSIC, /*49*/ CSWeapon_KNIFE_CORD, 
// /*50*/ CSWeapon_KNIFE_CANIS, /*51*/ CSWeapon_KNIFE_OUTDOOR, /*52*/ CSWeapon_KNIFE_SKELETON
// };


stock int ClientGetWeapon(int client, CSWeaponID weaponId) {
  int offset = Client_GetWeaponsOffset(client) - 4;
  int weapon = INVALID_ENT_REFERENCE;
  for (int i=0; i < MAX_WEAPONS; i++) {
    offset += 4;
    weapon = GetEntDataEnt2(client, offset);
    if (!Weapon_IsValid(weapon)) {
      continue;
    }
    int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    if (CS_ItemDefIndexToID(index) == weaponId) {
      return weapon;
    }
  }
  return INVALID_ENT_REFERENCE;
}

// public bool GetWeaponClass(int entity, char[] class, int size) {
//   int index = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
//   switch(index) {
//     case 42: {
//       FormatEx(class, size, "weapon_knife");
//       return true;
//     }
//     case 59: {
//       FormatEx(class, size, "weapon_knife_t");
//       return true;
//     }
//     case 43: {
//       FormatEx(class, size, "weapon_flashbang");
//       return true;
//     }
//     case 44: {
//       FormatEx(class, size, "weapon_hegrenade");
//       return true;
//     }
//     case 45: {
//       FormatEx(class, size, "weapon_smokegrenade");
//       return true;
//     }
//     case 45: {
//       FormatEx(class, size, "weapon_molotov");
//       return true;
//     }
//     case 47: {
//       FormatEx(class, size, "weapon_decoy");
//       return true;
//     }
//     case 48: {
//       FormatEx(class, size, "weapon_incgrenade");
//       return true;
//     }
//     default: {
//       for(int i = 0; i < sizeof(g_iWeaponDefIndex); i++) {
//         if(g_iWeaponDefIndex[i] == index) {
//           FormatEx(class, size, g_WeaponClasses[i]);
//           return true;
//         }
//       }
//     }
//   }
// 	return false;
// }

public int SortFuncADT_ByEndTime(int index1, int index2, Handle arrayHndl, Handle hndl) {
  char path1[PLATFORM_MAX_PATH], path2[PLATFORM_MAX_PATH];
  ArrayList array = view_as<ArrayList>(arrayHndl);
  array.GetString(index1, path1, sizeof(path1));
  array.GetString(index2, path2, sizeof(path2));

  S_FileData header1, header2;
  g_hLoadedRecords.GetArray(path1, header1, sizeof(header1));
  g_hLoadedRecords.GetArray(path2, header2, sizeof(header2));

  return header1.recordEndTime - header2.recordEndTime;
}

void SortRecordList() {
  SortADTArrayCustom(g_hSortedRecordList, SortFuncADT_ByEndTime);
  SortADTArray(g_hSortedCategoryList, Sort_Descending, Sort_String);
}

void BotMoveTo(int client, float fOrigin[3], RouteType routeType) {
	SDKCall(g_hVersusModeMoveTo, client, fOrigin, routeType);
}

bool LineGoesThroughSmoke(const float fFrom[3], const float fTo[3]) {
	return SDKCall(g_hVersusModeIsLineBlockedBySmoke, g_pVersusModeTheBots, fFrom, fTo);
} 

bool IsAbleToSee(int entity, int client, float spotValue) {
  // Skip all traces if the player isn't within the field of view.
  // - Temporarily disabled until eye angle prediction is added.
  // if (IsInFieldOfView(g_vEyePos[client], g_vEyeAngles[client], g_vAbsCentre[entity]))
  
  float vecOrigin[3], vecEyePos[3];
  GetClientAbsOrigin(entity, vecOrigin);
  GetClientEyePosition(client, vecEyePos);
  
  // Check if centre is visible.
  if (IsPointVisible(vecEyePos, vecOrigin)) {
      return true;
  }
  
  float vecEyePos_ent[3], vecEyeAng[3];
  GetClientEyeAngles(entity, vecEyeAng);
  GetClientEyePosition(entity, vecEyePos_ent);
  
  float mins[3], maxs[3];
  GetClientMins(client, mins);
  GetClientMaxs(client, maxs);
  // Check outer 4 corners of player.
  if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, spotValue)) {
      return true;
  }

  // Check if weapon tip is visible.
  // if (IsFwdVecVisible(vecEyePos, vecEyeAng, vecEyePos_ent)) {
  //     return true;
  // }

  // // Check outer 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 1.30)) {
  //     return true;
  // }
  // // Check inner 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 0.65)) {
  //     return true;
  // }

  return false;
}

bool IsRectangleVisible(const float start[3], const float end[3], const float mins[3], const float maxs[3], float scale=1.0) {
  float ZpozOffset = maxs[2];
  float ZnegOffset = mins[2];
  float WideOffset = ((maxs[0] - mins[0]) + (maxs[1] - mins[1])) / 4.0;

  // This rectangle is just a point!
  if (ZpozOffset == 0.0 && ZnegOffset == 0.0 && WideOffset == 0.0) {
      return IsPointVisible(start, end);
  }

  // Adjust to scale.
  ZpozOffset *= scale;
  ZnegOffset *= scale;
  WideOffset *= scale;
  
  // Prepare rotation matrix.
  float angles[3], fwd[3], right[3];

  SubtractVectors(start, end, fwd);
  NormalizeVector(fwd, fwd);

  GetVectorAngles(fwd, angles);
  GetAngleVectors(angles, fwd, right, NULL_VECTOR);

  float vRectangle[4][3], vTemp[3];

  // If the player is on the same level as us, we can optimize by only rotating on the z-axis.
  if (FloatAbs(fwd[2]) <= 0.7071) {
    ScaleVector(right, WideOffset);
    // Corner 1, 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vRectangle[0]);
    SubtractVectors(vTemp, right, vRectangle[1]);
    // Corner 3, 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vRectangle[2]);
    SubtractVectors(vTemp, right, vRectangle[3]);
  } else if (fwd[2] > 0.0) { // Player is below us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);
    
    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[3]);
  } else { // Player is above us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);

    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[3]);
  }

  // Run traces on all corners.
  for (int i = 0; i < 4; i++) {
    if (IsPointVisible(start, vRectangle[i])) {
        return true;
    }
  }

  return false;
}

stock bool CheckCreateDirectory(const char[] sPath, int mode) {
  if (!DirExists(sPath)) {
    CreateDirectory(sPath, mode);
    if (!DirExists(sPath)) {
      PrintToServer("[CheckCreateDirectory]Can't create a new directory. Please create one manually! (%s)", sPath);
      return false;
    }
  }
  return true;
}