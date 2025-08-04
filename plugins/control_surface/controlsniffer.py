import serial
import serial.tools.list_ports

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

print(f"Connected to {port}")
while True:
    if ser.in_waiting:
        line = ser.readline().decode().strip()
        print(f"Received: {line}")
