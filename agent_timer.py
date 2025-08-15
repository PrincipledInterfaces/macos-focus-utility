from threading import Timer
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QPushButton, QDialog

#timer/reminder system for the agent (for sending notifications after x amount of time.)
def set_timer(minutes, content):
    #creates notification after x minutes lol this is so simple does it need this much documentation?
    def notify():
        # Show notification dialog
        timer_dialog = QDialog()
        timer_dialog.setWindowTitle("Agent Notification")
        timer_dialog.setWindowFlags(Qt.Window | Qt.WindowStaysOnTopHint)
        timer_dialog.setFixedSize(300, 150)
        layout = QVBoxLayout()
        label = QLabel(f"{content}")
        layout.addWidget(label)
        button = QPushButton("OK")
        button.clicked.connect(timer_dialog.accept)
        layout.addWidget(button)
        timer_dialog.setLayout(layout)
        timer_dialog.exec_()
    
    time = minutes * 60  # convert minutes to seconds
    t = Timer(time, notify())
    t.start()