from threading import Timer
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QObject
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QPushButton, QDialog, QApplication
import subprocess

class TimerNotifier(QObject):
    """Qt object for handling timer notifications in the main thread"""
    show_notification = pyqtSignal(str)
    
    def __init__(self):
        super().__init__()
        self.show_notification.connect(self._show_dialog)
    
    def _show_dialog(self, content):
        """Show notification dialog in main thread"""
        try:
            # Try to show Qt dialog if app is running
            app = QApplication.instance()
            if app:
                timer_dialog = QDialog()
                timer_dialog.setWindowTitle("Agent Reminder")
                timer_dialog.setWindowFlags(Qt.Dialog | Qt.WindowStaysOnTopHint | Qt.WindowSystemMenuHint)
                timer_dialog.setFixedSize(400, 180)
                timer_dialog.setModal(True)  # Make it modal to ensure visibility
                timer_dialog.setStyleSheet("""
                    QDialog {
                        background-color: #f5f5f7;
                        border-radius: 10px;
                    }
                    QLabel {
                        font-size: 16px;
                        color: #1d1d1f;
                        padding: 20px;
                    }
                    QPushButton {
                        background-color: #007aff;
                        color: white;
                        border: none;
                        border-radius: 8px;
                        padding: 12px 24px;
                        font-size: 14px;
                        font-weight: 600;
                        margin: 10px;
                    }
                    QPushButton:hover {
                        background-color: #0056cc;
                    }
                """)
                
                layout = QVBoxLayout()
                label = QLabel(f"Reminder: {content}")
                label.setWordWrap(True)
                label.setAlignment(Qt.AlignCenter)
                layout.addWidget(label)
                
                button = QPushButton("Got it!")
                button.clicked.connect(timer_dialog.accept)
                button.setDefault(True)  # Make it the default button
                layout.addWidget(button, 0, Qt.AlignCenter)
                
                timer_dialog.setLayout(layout)
                
                # Center the dialog on screen
                from PyQt5.QtWidgets import QDesktopWidget
                screen = QDesktopWidget().screenGeometry()
                size = timer_dialog.geometry()
                timer_dialog.move(
                    (screen.width() - size.width()) // 2,
                    (screen.height() - size.height()) // 2
                )
                
                # Show with exec_ to make it blocking and ensure it appears
                timer_dialog.exec_()
            else:
                # Fallback to system notification if no Qt app
                self._show_system_notification(content)
                
        except Exception as e:
            print(f"Error showing timer dialog: {e}")
            # Fallback to system notification
            self._show_system_notification(content)
    
    def _show_system_notification(self, content):
        """Fallback system notification"""
        try:
            # Try plyer first
            from plyer import notification
            notification.notify(
                title='Agent Reminder',
                message=content,
                timeout=10
            )
        except:
            try:
                # Fallback to AppleScript
                subprocess.run([
                    'osascript', '-e', 
                    f'display notification "{content}" with title "Agent Reminder" sound name "Glass"'
                ], check=False, timeout=3)
            except:
                # Last resort: console message
                print(f"\nAGENT REMINDER: {content}\n")

# Global notifier instance
_notifier = TimerNotifier()

def set_timer(minutes, content):
    """Creates notification after x minutes"""
    def notify():
        print(f"DEBUG: Timer triggered after {minutes} minutes: {content}")
        _notifier.show_notification.emit(content)
    
    try:
        time_seconds = float(minutes) * 60  # convert minutes to seconds
        print(f"DEBUG: Setting timer for {minutes} minutes ({time_seconds} seconds)")
        
        # Fixed: Remove parentheses - pass function reference, not call it
        timer = Timer(time_seconds, notify)
        timer.start()
        
        print(f"Timer set successfully for {minutes} minutes: {content}")
        
    except Exception as e:
        print(f"Error setting timer: {e}")
        raise