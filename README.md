# cyberpunk-coop-fix

Fixes NightCoop crashes and lost sync for two players on Linux (Steam/Proton).
Installs NightCoop 0.2.1-beta (checksum-checked from nightcoop.net) and turns off the Let There Be Flight mod.
Backs up your saves and old NightCoop first. Close the game, then run:

    curl -fsSL https://raw.githubusercontent.com/Abdullahalmutairi97/cyberpunk-coop-fix/main/fix-coop.sh | bash

Achievement tracker for the same setup: https://github.com/Abdullahalmutairi97/cp2077-achievement-hunter

## Game crashing? Collect the logs

Close the game after the crash, then run:

    curl -fsSL https://raw.githubusercontent.com/Abdullahalmutairi97/cyberpunk-coop-fix/main/collect-logs.sh | bash

It makes a `cyberpunk-logs-<date>.tar.gz` file on your Desktop. Send that file to your friend. It only reads and copies logs; nothing in the game is changed.
