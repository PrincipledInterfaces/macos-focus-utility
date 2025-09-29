#!/usr/bin/env python3

"""
Test file for quick multi-section session transitions
Creates a session with 30-second sections to test:
- Video transitions
- Plugin triggers (WiFi lamp, etc.)
- Fade effects
- Multi-section flow
- Progress popups
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from focus_launcher import FocusLauncher
from PyQt5.QtWidgets import QApplication

def create_test_session():
    """Create a test session with quick 30-second sections"""
    
    # Test goals for the session
    test_goals = [
        "Test productivity mode transition",
        "Test creativity mode transition", 
        "Test social media detox transition",
        "Verify plugin triggers work",
        "Check video fade effects"
    ]
    
    # Create artificial AI analysis with 30-second sections
    test_ai_analysis = {
        'session_structure': [
            {
                'mode': 'productivity',
                'duration_minutes': 0.5,  # 30 seconds
                'todos': [
                    "Test productivity mode transition",
                    "Verify plugin triggers work"
                ],
                'description': 'Quick productivity test'
            },
            {
                'mode': 'creativity', 
                'duration_minutes': 0.5,  # 30 seconds
                'todos': [
                    "Test creativity mode transition",
                    "Check video fade effects"
                ],
                'description': 'Quick creativity test'
            },
            {
                'mode': 'social_media_detox',
                'duration_minutes': 0.5,  # 30 seconds  
                'todos': [
                    "Test social media detox transition"
                ],
                'description': 'Quick social media detox test'
            }
        ],
        'total_duration': 1.5,  # 1.5 minutes total
        'prioritized_goals': [
            {
                'goal': goal,
                'estimated_minutes': 0.3,
                'mode': ['productivity', 'creativity', 'social_media_detox'][i % 3],
                'priority': 'high',
                'urgency_reason': 'Testing'
            }
            for i, goal in enumerate(test_goals)
        ]
    }
    
    return test_goals, test_ai_analysis

def main():
    """Run the test session"""
    print("🧪 Starting Test Multi-Section Session")
    print("=" * 50)
    print("Each section: 30 seconds")
    print("Total session: 1.5 minutes") 
    print("Sections: Productivity → Creativity → Social Media Detox")
    print("=" * 50)
    
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    
    # Create test data
    test_goals, test_ai_analysis = create_test_session()
    
    try:
        # Initialize plugin system for testing
        from plugin_system import plugin_manager
        print("🔌 Plugin system initialized for testing")
    except Exception as e:
        print(f"⚠️  Plugin system error: {e}")
    
    print("🎬 Creating multi-section session manager...")
    
    # Create the multi-section session manager directly
    from focus_launcher import MultiSectionSessionManager
    session_manager = MultiSectionSessionManager(
        test_ai_analysis['session_structure'], 
        test_goals, 
        app
    )
    
    print("🚀 Starting test session...")
    print("\n📋 What to expect:")
    print("1. First video (productivity) - plugins trigger at 50%")
    print("2. 30s progress popup with productivity todos")
    print("3. Second video (creativity) - plugins trigger again")
    print("4. 30s progress popup with creativity todos") 
    print("5. Third video (social media detox) - plugins trigger")
    print("6. 30s progress popup with detox todos")
    print("7. Final session summary")
    print("\n⏰ Total test time: ~3-4 minutes (including videos)")
    print("💡 Watch for WiFi lamp triggers during videos!")
    print("\n" + "=" * 50)
    
    # Start the session
    session_manager.start_session()
    
    # Run the application
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()