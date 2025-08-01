#!/usr/bin/env python3

"""
Focus Mode CLI
Command-line interface for launching focus sessions directly
Usage: python focusmode.py [mode] [duration] [--goals "goal1;goal2"]
"""

import sys
import argparse
import os
from PyQt5.QtWidgets import QApplication, QDialog
from focus_launcher import TimePickerDialog, GoalsDialog, GoalsReviewDialog, CountdownWindow, FocusLauncher, PluginTaskDialog, FinalGoalsDialog


def main():
    parser = argparse.ArgumentParser(
        description='Launch a focus session directly from command line',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Hybrid mode (GUI dialogs but skip mode selector):
  python focusmode.py productivity                 # Shows duration picker, goals dialog, etc.
  python focusmode.py social --goals "Check email" # Use provided goals, show duration picker
  python focusmode.py deep 90                      # Use provided duration, show goals dialog
  
  # Full CLI mode (no GUI dialogs):
  python focusmode.py social 60 --no-gui          # Fully automated session
  python focusmode.py productivity 90 --goals "Finish report;Review emails" --no-gui
  
  # Other options:
  python focusmode.py deep 120 --no-countdown     # Skip countdown screen
  python focusmode.py --list                      # List available focus modes  
  python focusmode.py --status social             # Show mode details
        '''
    )
    
    parser.add_argument('mode', nargs='?', 
                       help='Focus mode to activate (social, productivity, creativity)')
    parser.add_argument('duration', nargs='?', type=int,
                       help='Session duration in minutes (if not provided, shows duration picker)')
    parser.add_argument('--goals', type=str,
                       help='Semicolon-separated list of goals for the session')
    parser.add_argument('--no-countdown', action='store_true',
                       help='Skip the countdown screen')
    parser.add_argument('--no-website-blocking', action='store_true',
                       help='Disable website blocking for this session')
    parser.add_argument('--no-gui', action='store_true',
                       help='Skip all GUI dialogs and use only command line arguments')
    parser.add_argument('--list', action='store_true',
                       help='List available focus modes')
    parser.add_argument('--status', type=str,
                       help='Show status and details for a specific mode')
    parser.add_argument('--deactivate', action='store_true',
                       help='Deactivate any active focus mode')
    
    args = parser.parse_args()
    
    # Handle utility commands
    if args.list:
        list_modes()
        return
    
    if args.status:
        show_mode_status(args.status)
        return
        
    if args.deactivate:
        deactivate_mode()
        return
    
    # Validate mode
    if not args.mode:
        print("Error: Mode is required. Use --list to see available modes.")
        return
    
    available_modes = ['productivity', 'creativity', 'social']
    if args.mode not in available_modes:
        print(f"Error: Invalid mode '{args.mode}'. Available modes: {', '.join(available_modes)}")
        return
    
    # For full CLI mode, require both mode and duration
    if args.no_gui and not args.duration:
        print("Error: Duration is required when using --no-gui")
        return
    
    # Initialize Qt application
    app = QApplication(sys.argv)
    
    try:
        # Initialize plugin system
        from plugin_system import plugin_manager
    except Exception as e:
        print(f"Plugin system initialization error: {e}")
    
    # Run the CLI session
    run_cli_session(app, args)


def list_modes():
    """List available focus modes"""
    print("Available Focus Modes:")
    print("  productivity - Work and focus apps only")
    print("  creativity   - Design and creative tools")
    print("  social       - Communication and collaboration")


def show_mode_status(mode):
    """Show status for a specific mode"""
    available_modes = ['productivity', 'creativity', 'social']
    if mode not in available_modes:
        print(f"Error: Invalid mode '{mode}'. Available modes: {', '.join(available_modes)}")
        return
    
    print(f"Mode: {mode.title()}")
    
    # Try to read the mode file
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        mode_file = os.path.join(script_dir, 'modes', f'{mode}.txt')
        
        if os.path.exists(mode_file):
            with open(mode_file, 'r') as f:
                apps = [line.strip() for line in f.readlines() if line.strip()]
            print(f"Allowed apps: {len(apps)} applications")
            if len(apps) <= 10:
                for app in apps:
                    print(f"  • {app}")
            else:
                for app in apps[:10]:
                    print(f"  • {app}")
                print(f"  ... and {len(apps) - 10} more")
        else:
            print("Mode file not found")
    except Exception as e:
        print(f"Error reading mode file: {e}")


def deactivate_mode():
    """Deactivate any active focus mode"""
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        os.chdir(script_dir)
        
        import subprocess
        subprocess.run(['bash', './stop_focus_mode.sh'], timeout=10)
        print("Focus mode deactivated")
    except Exception as e:
        print(f"Error deactivating focus mode: {e}")


def run_cli_session(app, args):
    """Run a focus session with CLI parameters"""
    
    # Determine session duration
    if args.duration:
        session_duration = args.duration
    elif not args.no_gui:
        # Show duration picker
        time_picker = TimePickerDialog()
        if time_picker.exec_() != QDialog.Accepted:
            print("No duration selected. Exiting.")
            return
        session_duration = time_picker.duration_minutes
    else:
        print("Error: Duration required for --no-gui mode")
        return
    
    # Determine goals
    analyzed_goals = []
    if args.goals:
        # Parse provided goals
        goal_list = [goal.strip() for goal in args.goals.split(';') if goal.strip()]
        analyzed_goals = [f"• {goal}" for goal in goal_list]
    elif not args.no_gui:
        # Show goals dialog
        goals_dialog = GoalsDialog()
        if goals_dialog.exec_() != QDialog.Accepted:
            print("No goals specified. Exiting.")
            return
        
        analyzed_goals = goals_dialog.analyzed_goals
        
        # Show goals review dialog 
        goals_review = GoalsReviewDialog(analyzed_goals)
        goals_review.used_ai = getattr(goals_dialog, 'used_ai', False)
        review_result = goals_review.exec_()
        
        if review_result == QDialog.Rejected:
            print("Goals review cancelled. Exiting.")
            return
        elif not goals_review.approved:
            print("Goals review not approved. Exiting.")
            return
    else:
        # No goals for CLI mode - that's okay
        analyzed_goals = []
    
    # Handle plugin task scanning (unless no-gui)
    final_goals = analyzed_goals
    if not args.no_gui:
        plugin_scan = PluginTaskDialog(analyzed_goals)
        if plugin_scan.exec_() != QDialog.Accepted:
            print("Plugin task scanning cancelled. Exiting.")
            return
        
        final_goals = plugin_scan.final_goals
        
        # Show final goals if plugin tasks were added
        if len(final_goals) > len(analyzed_goals):
            final_review = FinalGoalsDialog(final_goals)
            if final_review.exec_() != QDialog.Accepted:
                print("Final goals review cancelled. Exiting.")
                return
    
    # Show countdown (unless skipped)
    if not args.no_countdown:
        countdown = CountdownWindow(args.mode)
        countdown.show()
        app.exec_()
    
    # Launch focus mode
    launcher = FocusLauncher()
    use_website_blocking = not args.no_website_blocking
    launcher.launch_focus_mode(args.mode, use_website_blocking)
    
    # Start progress tracking with final goals
    from focus_launcher import ProgressPopup, get_popup_interval_setting
    popup_interval = get_popup_interval_setting()
    print(f"DEBUG: CLI using popup interval: {popup_interval} minutes")
    progress_popup = ProgressPopup(session_duration, final_goals, popup_interval=popup_interval)
    
    # Set progress popup reference for plugin system
    try:
        from plugin_system import plugin_manager
        plugin_manager.set_progress_popup_reference(progress_popup)
    except Exception as e:
        print(f"Error setting progress popup reference: {e}")
    
    print(f"{args.mode.title()} focus mode activated for {session_duration} minutes!")
    if final_goals:
        print(f"{len(final_goals)} goals loaded")
    
    # Keep the application running during the session
    app.exec_()


if __name__ == "__main__":
    main()