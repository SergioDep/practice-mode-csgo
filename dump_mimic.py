import sys
import time
import numpy as np
import webbrowser
filePath = sys.argv[1]
print('Abriendo archivo:', filePath, type(filePath))

html = '<html><body> <h1 style="color: #5e9ca0;">Demo<span style="color: #2b2301;"> Demo</span> Dump!</h1>'

EXTRA_PLAYERDATA_HEALTH       = (1 << 0)
EXTRA_PLAYERDATA_HELMET       = (1 << 1)
EXTRA_PLAYERDATA_ARMOR        = (1 << 2)
EXTRA_PLAYERDATA_ON_GROUND    = (1 << 3)
EXTRA_PLAYERDATA_GRENADE      = (1 << 4)
EXTRA_PLAYERDATA_INVENTORY    = (1 << 5)
EXTRA_PLAYERDATA_EQUIPWEAPON  = (1 << 6)
EXTRA_PLAYERDATA_MONEY        = (1 << 7)
EXTRA_PLAYERDATA_CHAT         = (1 << 8)

if filePath.endswith('.rec'):
  with open(filePath, 'rb') as file:
    magic = np.fromfile(file, dtype=np.uint32, count=1)
    if magic == 0xdeadbeef:
      html = html + ('<h2 style="color: #2e6c80;">Header</h2>')

      binaryVersion = np.fromfile(file, dtype=np.uint8, count=1)[0]
      html = html + ('<p style="font-size:11px;">Binary version: {0}</p>'.format(binaryVersion))

      iRecordTime = np.fromfile(file, dtype=np.int32, count=1)[0]
      html = html + ('<p style="font-size:11px;">Record time: {0}</p>'.format(iRecordTime))

      iNameLength = np.fromfile(file, dtype=np.int8, count=1)[0]
      sRecordName = np.fromfile(file, dtype=np.byte, count=iNameLength)
      html = html + ('<p style="font-size:11px;">Name: {0}</p>'.format(sRecordName.tobytes().decode('utf-8')))

      playerSpawnPos = np.fromfile(file, dtype=np.float32, count=3)
      html = html + ('<p style="font-size:11px;">Initial position: {0}</p>'.format(playerSpawnPos.tolist()))

      playerSpawnAng = np.fromfile(file, dtype=np.float32, count=2)
      html = html + ('<p style="font-size:11px;">Initial angles: {0}</p>'.format(playerSpawnAng.tolist()))

      iTickCount = np.fromfile(file, dtype=np.int32, count=1)[0]
      html = html + ('<p style="font-size:11px;">Tickcount: {0}</p>'.format(iTickCount))

      iTickRate = np.fromfile(file, dtype=np.int32, count=1)[0]
      html = html + ('<p style="font-size:11px;">TickRate: {0}</p>'.format(iTickRate))

      html = html + ('<h2 style="color: #2e6c80;">Frames</h2>')
      for i in range(iTickCount):
        html = html + ('<p style="font-size:11px;">{0}. '.format(i))
        
        playerButtons = np.fromfile(file, dtype=np.int32, count=1)[0]
        html = html + ('buttons: {0}, '.format(playerButtons))
        
        playerOrigin = np.fromfile(file, dtype=np.float32, count=3)
        html = html + ('position: {0}, '.format(playerOrigin.tolist()))
        
        playerAngles = np.fromfile(file, dtype=np.float32, count=2)
        html = html + ('eye_angles: {0}, '.format(playerAngles.tolist()))
        
        playerVelocity = np.fromfile(file, dtype=np.float32, count=3)
        html = html + ('velocity: {0}, '.format(playerVelocity.tolist()))
        
        extraData = np.fromfile(file, dtype=np.int32, count=1)[0]
        
        if (extraData > 0):
          html = html + ('<p style="font-size:11px;">--> ExtraData: {0}</p>'.format(extraData))
          if (extraData & EXTRA_PLAYERDATA_HEALTH):
            playerHealth = np.fromfile(file, dtype=np.int32, count=1)[0]
            html = html + ('<p style="font-size:11px;">--> health: {0}</p>'.format(playerHealth))

          if (extraData & EXTRA_PLAYERDATA_HELMET):
            playerHelmet = np.fromfile(file, dtype=np.bool_, count=1)[0]
            html = html + ('<p style="font-size:11px;">--> helmet: {0}</p>'.format(playerHelmet))

          if (extraData & EXTRA_PLAYERDATA_ARMOR):
            playerArmor = np.fromfile(file, dtype=np.int32, count=1)[0]
            html = html + ('<p style="font-size:11px;">--> armor: {0}</p>'.format(playerArmor))

          if (extraData & EXTRA_PLAYERDATA_ON_GROUND):
            playerOnGround = np.fromfile(file, dtype=np.bool_, count=1)[0]
            html = html + ('<p style="font-size:11px;">--> OnGround: {0}</p>'.format(playerOnGround))

          if (extraData & EXTRA_PLAYERDATA_GRENADE):
            grenadeType = np.fromfile(file, dtype=np.int32, count=1)[0]
            html = html + ('<p style="font-size:11px;">--> grenadeType: {0}</p>'.format(grenadeType))
            grenadePos = np.fromfile(file, dtype=np.float32, count=3)
            html = html + ('<p style="font-size:11px;">--> grenade_pos: {0}</p>'.format(grenadePos.tolist()))
            grenadeVel = np.fromfile(file, dtype=np.float32, count=3)
            html = html + ('<p style="font-size:11px;">--> grenade_velocity: {0}</p>'.format(grenadeVel.tolist()))

          # if (extraData & EXTRA_PLAYERDATA_INVENTORY):
          #   playerGrenade = np.fromfile(file, dtype=np.int32, count=1)[0]
          #   html = html + ('Grenade: {0}, '.format(playerGrenade))

          if (extraData & EXTRA_PLAYERDATA_EQUIPWEAPON):
            weapon = np.fromfile(file, dtype=np.int32, count=1)[0]
            html = html + ('<p style="font-size:11px;">--> activeWeapon: {0}</p>'.format(weapon))

          if (extraData & EXTRA_PLAYERDATA_MONEY):
            money = np.fromfile(file, dtype=np.int32, count=1)[0]
            html = html + ('<p style="font-size:11px;">--> money: {0}</p>'.format(money))

          # if (extraData & EXTRA_PLAYERDATA_CHAT):
          #   atVelocity = np.fromfile(file, dtype=np.float32, count=3)
          #   html = html + ('<p style="font-size:11px;">--> teleport_velocity: '.format(atVelocity.tolist()))
html = html + ('</body></html>')
with open(sys.path[0]+'/output.html', 'w') as f:
  f.write(html)
  webbrowser.open('file://' + f.name)
  f.seek(0)
