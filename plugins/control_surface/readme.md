# Control Surface
## Control Sniffer
The control sniffer ([controlsniffer.py](controlsniffer.py)), is a script that checks for the USB control surface (via an ESP 8266 in this version) and receives button input commands. It is reccomended that for regular control surface use, this script is added to your system's startup programs so that it will automatically run. Controlsniffer operates as a script seperate from the main program, but interacts with it. 

It is also reccomended that if you intend on using the plugin, controlsniffer is launched prior to launching the main application.

## Main Plugin
Currently, the [main plugin](plugin.py) handles portions of the queueing system, but will likely handle plugin configuration (for button bindings, etc) in the future.

For functionality of control surface interaction, ensure that controlsniffer is running and the plugin is enabled in the focus utility settings.

-Matthew Reichard