#!/usr/bin/env python3

import serial
import serial.tools.list_ports

#open queued mode file, overwrite as blank.


def find_esp8266():
    ports = serial.tools.list_ports.comports()
    for port in ports:
        # Match by known identifiers for ESP boards
        if ('USB' in port.description or 'wch' in port.description.lower() 
            or 'ESP' in port.description or 'usbserial' in port.device):
            return port.device
    return None

port = find_esp8266()
if not port:
    print("ESP8266 not found.")
    exit()

ser = serial.Serial(port, 9600, timeout=1)


def button_1_action():
    pass

def button_2_action():
    pass

def button_3_action():
    pass


#loop check for button signals
print(f"Connected to {port}")
while True:
    if ser.in_waiting:
        line = ser.readline().decode().strip()
        print(f"Received: {line}")
        if line is "button1":
            button_1_action()
        elif line is "button2":
            button_2_action()
        elif line is "button3":
            button_3_action()
