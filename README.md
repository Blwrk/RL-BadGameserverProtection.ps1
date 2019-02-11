# RL-BadGameserverProtection.ps1

Block bad Rocket League gameservers temporarily.

This script identifies Rocket League gameserver IP while joining, gets its average ping out of three and adds a temporary Nullroute if the ping is above a defined threshold.

## Launching

Launch an elevated Powershell and execute the script:
```PowerShell
.\RL-BadGameserverProtection.ps1
```

If the gameserver is declared good, this is the expected output:
```shell
Gameserver found:    1.2.3.4
Average Ping:        36ms
Packets Lost:        0/3
Have Fun!
```

If the gameserver is declared bad, this is the expected output:
```shell
Gameserver found:    4.3.2.1
Average Ping:        96ms
Packets Lost:        2/3
Adding Nullroute for 4.3.2.1 on Interface #3 for 600 Seconds
```

## Notes

- Keep in mind that the logic of this script does not protect against gameservers with good ping but high packet loss.
- The icmp response time and the ping displayed in game can vary by ~20ms. You can play with the -PingCutoff parameter to accommodate this if you are still getting too high ping.

## Configuration

#### Parameter PingCutoff
Type:		int
Default:	80

Define the maximum allowed ping in miliseconds, default is 80.

```PowerShell
.\RL-BadGameserverProtection.ps1 -PingCutoff 50
```

#### Parameter TimeOut
Type:		int
Default:	600

Define for how long a gameserver is blocked in seconds, default is 600 (10 minutes).

```PowerShell
.\RL-BadGameserverProtection.ps1 -TimeOut 1200
```

## Links

https://github.com/Blwrk/RL-BadGameserverProtection.ps1

## Licensing

This code is licensed under the "Do What The F*ck You Want To Public License", "wtfpl".
However, if you publish or use it in any way, a mention of this site would be nice.
