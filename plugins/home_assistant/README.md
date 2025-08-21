# Home Assistant Integration Plugin

Automatically activates Home Assistant scenes/presets based on your focus modes to create custom smart home environments for different types of work sessions.

## Features

- 🏠 **Smart Home Integration**: Controls your entire smart home based on focus mode
- 🎭 **Scene-Based Control**: Uses Home Assistant scenes for complex device orchestration
- 🎯 **Mode-Specific Environments**: Different smart home setups for productivity, creativity, and social media detox
- 🔄 **Automatic Restoration**: Returns to default scene when session ends
- ⚡ **Real-time Activation**: Instantly activates scenes when focus sessions start
- 🔧 **Easy Configuration**: User-friendly setup through GUI configuration dialog

## Use Cases

### Productivity Mode
- Bright, cool lighting for alertness
- Close blinds to minimize distractions
- Turn on white noise machine
- Set thermostat to optimal working temperature (68-72°F)
- Turn off entertainment devices

### Creativity Mode  
- Warm, ambient lighting to inspire creativity
- Open blinds for natural light
- Play background music
- Adjust temperature for comfort
- Turn off notification devices

### Social Media Detox Mode
- Minimal, focused lighting
- Block internet on entertainment devices
- Turn on "Do Not Disturb" modes
- Create distraction-free environment
- Enable meditation/focus sounds

### Default Mode
- Return all devices to normal operation
- Restore standard lighting and temperature
- Re-enable all devices and automations

## Requirements

- **Home Assistant**: Running instance with HTTP API enabled
- **Long-lived Access Token**: Generated from Home Assistant user profile
- **Network Access**: Plugin must be able to reach Home Assistant instance
- **Home Assistant Scenes**: Pre-configured scenes for each focus mode

## Setup Instructions

### 1. Home Assistant Preparation

#### Create Scenes
Create the following scenes in Home Assistant (you can customize names):

```yaml
# Example scene configurations
scene:
  - name: "Focus - Productivity"
    id: focus_productivity
    entities:
      light.office_light:
        state: on
        brightness: 255
        color_temp: 200  # Cool white
      climate.office:
        temperature: 70
      media_player.tv:
        state: off
      cover.office_blinds:
        state: closed

  - name: "Focus - Creativity"  
    id: focus_creativity
    entities:
      light.office_light:
        state: on
        brightness: 180
        color_temp: 400  # Warm white
      media_player.spotify:
        state: playing
        source: "Ambient Music Playlist"
      climate.office:
        temperature: 72

  - name: "Focus - Social Media Detox"
    id: focus_detox  
    entities:
      light.office_light:
        state: on
        brightness: 150
        color_temp: 300
      switch.router_guest_network:
        state: off
      media_player.all:
        state: off

  - name: "Focus - Default"
    id: focus_default
    entities:
      light.office_light:
        state: on  
        brightness: 200
        color_temp: 300
      climate.office:
        temperature: 72
      switch.router_guest_network:
        state: on
```

#### Generate Access Token
1. Open Home Assistant web interface
2. Go to your User Profile (click your name in sidebar)
3. Scroll down to "Long-Lived Access Tokens"
4. Click "Create Token"
5. Give it a name like "Focus Utility"
6. Copy the generated token (save it securely)

### 2. Plugin Configuration

1. **Enable Plugin**: Go to Focus Utility Settings → Plugins and enable "Home Assistant Integration"

2. **Configure Connection**: Click "Configure Home Assistant" button

3. **Enter Connection Details**:
   - **Home Assistant URL**: `http://homeassistant.local:8123` (adjust for your setup)
   - **Access Token**: Paste the long-lived access token from step 1

4. **Test Connection**: Click "🔍 Test Connection" to verify everything works

5. **Refresh Scenes**: Click "🔄 Refresh Available Scenes" to load your scenes

6. **Assign Scenes**: Select appropriate scenes for each focus mode:
   - **Productivity Scene**: Your productivity-optimized scene
   - **Creativity Scene**: Your creativity-optimized scene  
   - **Social Media Detox Scene**: Your distraction-free scene
   - **Default Scene**: Your normal/default scene

7. **Enable Integration**: Check "Enable Integration" checkbox

8. **Save Settings**: Click "Save" to apply configuration

## Configuration Options

### Connection Settings
- **Home Assistant URL**: Full URL including protocol and port
- **Access Token**: Long-lived access token for authentication
- **Timeout**: Request timeout in seconds (default: 10)
- **SSL Verification**: Enable/disable SSL certificate verification

### Scene Mapping
- **Productivity Scene**: Activated during productivity focus sessions
- **Creativity Scene**: Activated during creativity focus sessions  
- **Social Media Detox Scene**: Activated during social media detox sessions
- **Default Scene**: Activated when no focus session is active

## Advanced Configuration

### Custom Scene Entity IDs
You can manually enter scene entity IDs if they don't appear in the dropdown:
- Format: `scene.your_scene_name`
- Example: `scene.focus_productivity`

### SSL/TLS Configuration
For HTTPS Home Assistant instances:
- Enable SSL verification for production setups
- Disable only for development/testing with self-signed certificates

### Network Considerations
- Ensure Home Assistant is accessible from the machine running Focus Utility
- Default port is 8123, but may vary based on your setup
- For external access, use your external URL and ensure port forwarding is configured

## Troubleshooting

### Connection Issues

**"Connection failed: Connection refused"**
- Verify Home Assistant URL and port
- Ensure Home Assistant is running and accessible
- Check firewall settings

**"Connection failed: Invalid authentication"** 
- Verify access token is correct and not expired
- Regenerate token if necessary
- Ensure token has proper permissions

**"Connection failed: SSL verification failed"**
- Disable SSL verification for local/development instances
- Install proper certificates for production instances

### Scene Issues

**"No scenes found"**
- Verify scenes are properly configured in Home Assistant
- Check that scenes have proper entity IDs
- Ensure access token has permission to view scenes

**"Scene activation failed"**
- Verify scene entity IDs are correct
- Check that all devices in scene are available
- Review Home Assistant logs for detailed error information

### Plugin Issues

**"Plugin not loaded"**
- Enable the plugin in Settings → Plugins
- Restart Focus Utility if needed
- Check plugin files are properly installed

## Example Home Assistant Automation

You can also create automations that respond to scene activation:

```yaml
automation:
  - alias: "Focus Mode Notification"
    trigger:
      - platform: state
        entity_id: scene.focus_productivity
    action:
      - service: notify.mobile_app
        data:
          title: "Focus Mode Active"
          message: "Productivity mode activated - smart home optimized for work"
```

## Technical Details

### Communication Protocol
- HTTP REST API over WiFi/Ethernet
- JSON request/response format
- Bearer token authentication

### API Endpoints Used
- `GET /api/` - Service information and connectivity test
- `GET /api/states` - Retrieve available scenes
- `POST /api/services/scene/turn_on` - Activate scenes

### Security Considerations
- Access tokens are stored locally in plugin settings
- Tokens are never transmitted except to configured Home Assistant instance
- Use HTTPS for production environments
- Regularly rotate access tokens for security

## Files Structure

```
plugins/home_assistant/
├── manifest.json              # Plugin metadata
├── plugin.py                  # Main plugin code  
├── README.md                  # This documentation
└── ha_settings.json          # Auto-generated settings file
```

## Version History

- **v1.0.0**: Initial release with scene activation and configuration UI

## Support

For issues or questions:
1. Check Home Assistant logs for detailed error information
2. Verify network connectivity between Focus Utility and Home Assistant
3. Ensure all scenes and devices are properly configured
4. Test scene activation manually in Home Assistant first

The plugin provides comprehensive smart home integration to enhance your focus sessions with environmental optimization.