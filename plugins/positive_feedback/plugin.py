from abc import ABC, abstractmethod
from typing import Dict, List, Any
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QPushButton, QDialog
from plugin_system import PluginBase

affirmations = [
    "Great job!",
    "Keep up the good work!",
    "You're making progress!",
    "Fantastic effort!",
    "You're doing amazing!",
    "Every step counts!",
    "You're on the right track!",
    "Keep pushing forward!",
    "You're getting closer to your goal!",
    "Your hard work is paying off!"
]

previous_completion = 0

class Plugin(PluginBase):
    
    def __init__(self):
        super().__init__()
        self.name = "Positive Feedback"
        self.version = "1.0.0"
        self.description = "Gives small positive notifications as goal progress is made."

    def initialize(self) -> bool:
        print("Positive Feedback plugin initialized!")
        return True


    def cleanup(self):
        pass


    def on_checklist_item_changed(self, item_text: str, is_checked: bool):
        global previous_completion
        progress_percent = self.get_checklist_progress_percentage()
        if progress_percent > previous_completion and progress_percent is not 0:
            # Show positive feedback pos_dialog
            pos_dialog = QDialog()
            pos_dialog.setWindowTitle("Positive Feedback")
            pos_dialog.setWindowFlags(Qt.Window | Qt.WindowStaysOnTopHint)
            pos_dialog.setFixedSize(300, 150)
            layout = QVBoxLayout()
            label = QLabel(f"{affirmations[int(progress_percent / 10)]} You've now completed {int(progress_percent)}% of your session!")
            layout.addWidget(label)
            button = QPushButton("OK")
            button.clicked.connect(pos_dialog.accept)
            layout.addWidget(button)
            pos_dialog.setLayout(layout)
            pos_dialog.show()
            # Keep a reference to prevent garbage collection
            if not hasattr(self, '_active_dialogs'):
                self._active_dialogs = []
            self._active_dialogs.append(pos_dialog)
            # Remove from list when closed
            pos_dialog.finished.connect(lambda: self._active_dialogs.remove(pos_dialog) if pos_dialog in self._active_dialogs else None)
            #update previous completion percentage
            previous_completion = progress_percent