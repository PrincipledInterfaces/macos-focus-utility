#!/usr/bin/env python3

from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, 
                             QPushButton, QTextEdit, QLineEdit, QMessageBox,
                             QProgressDialog, QApplication)
from PyQt5.QtCore import Qt
from ai_service import ai_service

class CustomModeDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Create Custom Focus Mode')
        self.setFixedSize(600, 500)
        
        # Modal dialog
        self.setModal(True)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel("Create Custom Focus Mode")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 20px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel("Describe your ideal focus environment and let AI configure it for you")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setStyleSheet("""
            font-size: 14px;
            color: #666666;
            margin-bottom: 20px;
        """)
        subtitle.setWordWrap(True)
        layout.addWidget(subtitle)
        
        # Mode name input
        name_label = QLabel("Mode Name:")
        name_label.setStyleSheet("""
            font-size: 14px;
            font-weight: 500;
            color: #1d1d1f;
            margin-bottom: 5px;
        """)
        layout.addWidget(name_label)
        
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("e.g., Deep Work, Writing, Research")
        self.name_input.setStyleSheet("""
            QLineEdit {
                padding: 10px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 6px;
                background-color: white;
                color: #1d1d1f;
            }
            QLineEdit:focus {
                border-color: #007AFF;
            }
        """)
        layout.addWidget(self.name_input)
        
        # Description input
        desc_label = QLabel("Description:")
        desc_label.setStyleSheet("""
            font-size: 14px;
            font-weight: 500;
            color: #1d1d1f;
            margin-bottom: 5px;
            margin-top: 15px;
        """)
        layout.addWidget(desc_label)
        
        desc_hint = QLabel("Describe the purpose of this focus mode, what you want to accomplish, and your ideal environment")
        desc_hint.setStyleSheet("""
            font-size: 12px;
            color: #666666;
            margin-bottom: 10px;
        """)
        desc_hint.setWordWrap(True)
        layout.addWidget(desc_hint)
        
        self.description_input = QTextEdit()
        self.description_input.setPlaceholderText("e.g., I want to focus on deep programming work without distractions. I need my development tools but want to block social media, news sites, and entertainment. This mode should help me enter a flow state for coding sessions.")
        self.description_input.setMinimumHeight(120)
        self.description_input.setStyleSheet("""
            QTextEdit {
                padding: 10px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 6px;
                background-color: white;
                color: #1d1d1f;
                line-height: 1.4;
            }
            QTextEdit:focus {
                border-color: #007AFF;
            }
        """)
        layout.addWidget(self.description_input)
        
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.setSpacing(15)
        
        cancel_button = QPushButton("Cancel")
        cancel_button.setStyleSheet("""
            QPushButton {
                background-color: #f0f0f0;
                color: #1d1d1f;
                border: 1px solid #d1d1d6;
                border-radius: 6px;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: #e0e0e0;
            }
            QPushButton:pressed {
                background-color: #d0d0d0;
            }
        """)
        cancel_button.clicked.connect(self.reject)
        
        create_button = QPushButton("Create Mode")
        create_button.setStyleSheet("""
            QPushButton {
                background-color: #007AFF;
                color: white;
                border: none;
                border-radius: 6px;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: #0056CC;
            }
            QPushButton:pressed {
                background-color: #004499;
            }
            QPushButton:disabled {
                background-color: #cccccc;
                color: #666666;
            }
        """)
        create_button.clicked.connect(self.create_mode)
        
        button_layout.addStretch()
        button_layout.addWidget(cancel_button)
        button_layout.addWidget(create_button)
        
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
    
    def create_mode(self):
        """Create the custom mode using AI"""
        mode_name = self.name_input.text().strip()
        description = self.description_input.toPlainText().strip()
        
        if not mode_name:
            QMessageBox.warning(self, "Missing Information", "Please enter a mode name.")
            return
        
        if not description:
            QMessageBox.warning(self, "Missing Information", "Please enter a description of your focus mode.")
            return
        
        if not ai_service.is_available():
            QMessageBox.warning(self, "AI Service Unavailable", 
                              "AI service is not available. Please ensure your Groq API key is configured in groq_api_key.txt")
            return
        
        # Show progress dialog
        progress = QProgressDialog("Creating your custom focus mode...", "Cancel", 0, 100, self)
        progress.setWindowTitle("AI Mode Generation")
        progress.setMinimumDuration(0)
        progress.setValue(20)
        QApplication.processEvents()
        
        try:
            progress.setValue(40)
            QApplication.processEvents()
            
            if progress.wasCanceled():
                return
            
            # Create the mode using AI (let AI determine everything from description)
            success = ai_service.create_custom_mode(
                mode_name=mode_name,
                description=description
            )
            
            progress.setValue(100)
            QApplication.processEvents()
            
            progress.close()
            
            if success:
                QMessageBox.information(self, "Mode Created", 
                                      f"Successfully created custom focus mode '{mode_name}'!\n\n"
                                      f"You can now select this mode from the main focus mode selection.")
                self.accept()
            else:
                QMessageBox.critical(self, "Creation Failed", 
                                   "Failed to create the custom mode. Please check the console for error details.")
                
        except Exception as e:
            progress.close()
            print(f"Error creating custom mode: {e}")
            QMessageBox.critical(self, "Creation Error", 
                               f"An error occurred while creating the mode:\n\n{str(e)}")