#!/usr/bin/env python3

from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                             QLineEdit, QPushButton, QScrollArea, QGraphicsDropShadowEffect)
from PyQt5.QtCore import Qt, QTimer, QThread, pyqtSignal
from PyQt5.QtGui import QFont, QColor
import subprocess

class AIWorkerThread(QThread):
    """Background thread for AI processing to prevent UI freezing"""
    response_ready = pyqtSignal(str, object)  # (response, commands_used)
    error_occurred = pyqtSignal(str)  # error message
    
    def __init__(self, ai_service, ai_plugin, user_input, timeout_seconds=30):
        super().__init__()
        self.ai_service = ai_service
        self.ai_plugin = ai_plugin
        self.user_input = user_input
        self.timeout_seconds = timeout_seconds
        self._response_received = False
    
    def run(self):
        """Run in background thread with timeout"""
        # Start timeout timer
        timeout_timer = QTimer()
        timeout_timer.timeout.connect(self._on_timeout)
        timeout_timer.start(self.timeout_seconds * 1000)  # Convert to milliseconds
        
        try:
            from agent import chat
            response, commands_used = chat(self.ai_service, self.user_input, self.ai_plugin)
            
            # Stop timeout timer
            timeout_timer.stop()
            
            if not self._response_received:
                self._response_received = True
                
                # Check for empty response
                if not response or response.strip() == "":
                    self.error_occurred.emit("AI returned an empty response. Please try again.")
                else:
                    # Emit success signal
                    self.response_ready.emit(response, commands_used)
            
        except Exception as e:
            # Stop timeout timer
            timeout_timer.stop()
            
            if not self._response_received:
                self._response_received = True
                # Emit error signal
                self.error_occurred.emit(f"Sorry, I encountered an error: {e}")
    
    def _on_timeout(self):
        """Handle timeout"""
        if not self._response_received:
            self._response_received = True
            self.error_occurred.emit(f"AI request timed out after {self.timeout_seconds} seconds. Please try again.")

def get_app_icon():
    """Get the application icon for dock/window display"""
    try:
        import os
        script_dir = os.path.dirname(os.path.abspath(__file__))
        icon_path = os.path.join(script_dir, 'icon.png')
        
        if os.path.exists(icon_path):
            from PyQt5.QtGui import QIcon
            icon = QIcon(icon_path)
            # Verify the icon loaded successfully
            if not icon.isNull():
                return icon
        
        # Create a simple fallback icon
        from PyQt5.QtGui import QPixmap, QPainter, QBrush
        icon_pixmap = QPixmap(32, 32)
        icon_pixmap.fill(Qt.transparent)
        
        painter = QPainter(icon_pixmap)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Draw blue circle
        painter.setBrush(QBrush(QColor(0, 122, 255)))
        painter.setPen(Qt.NoPen)
        painter.drawEllipse(4, 4, 24, 24)
        
        # Draw white "F" in center
        painter.setPen(Qt.white)
        painter.setFont(QFont("Arial", 16, QFont.Bold))
        painter.drawText(icon_pixmap.rect(), Qt.AlignCenter, "F")
        painter.end()
        
        from PyQt5.QtGui import QIcon
        return QIcon(icon_pixmap)
        
    except Exception as e:
        print(f"Error creating app icon: {e}")
        from PyQt5.QtGui import QIcon
        return QIcon()

class AIAssistantWindow(QWidget):
    """AI Assistant chat window for focus sessions with proper bubble styling"""
    
    def __init__(self, ai_service, ai_plugin):
        super().__init__()
        self.ai_service = ai_service
        self.ai_plugin = ai_plugin
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('AI Assistant - Focus Helper')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(500, 600)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Center the window
        self.center_window()
        
        # Modern styling
        self.setStyleSheet("""
            AIAssistantWindow {
                background-color: #f5f5f7;
            }
            QLineEdit {
                background-color: white;
                border: 2px solid #d1d1d6;
                border-radius: 8px;
                padding: 10px;
                font-size: 14px;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            }
            QLineEdit:focus {
                border-color: #007aff;
            }
            QPushButton {
                background-color: #007aff;
                color: white;
                border: none;
                border-radius: 8px;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 600;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            }
            QPushButton:hover {
                background-color: #0056b3;
            }
            QPushButton:pressed {
                background-color: #004080;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        # Title
        title = QLabel("AI Focus Assistant")
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Chat display using scroll area for better styling control
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll_area.setStyleSheet("""
            QScrollArea {
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: #f5f5f7;
            }
            QScrollArea > QWidget > QWidget {
                background-color: #f5f5f7;
            }
        """)
        
        # Chat container widget
        self.chat_widget = QWidget()
        self.chat_layout = QVBoxLayout(self.chat_widget)
        self.chat_layout.setContentsMargins(10, 10, 10, 10)
        self.chat_layout.setSpacing(8)
        self.chat_layout.addStretch()  # Push messages to top
        
        scroll_area.setWidget(self.chat_widget)
        layout.addWidget(scroll_area)
        
        # Store scroll area reference for scrolling
        self.scroll_area = scroll_area
        
        # Add initial message
        self.add_message("AI", "Hello! I'm your AI assistant. I can help you stay focused and productive during your session.\n\nHow can I help you today?")
        
        # Input section
        input_layout = QHBoxLayout()
        
        self.chat_input = QLineEdit()
        self.chat_input.setPlaceholderText("Type your message here...")
        self.chat_input.returnPressed.connect(self.send_message)
        input_layout.addWidget(self.chat_input)
        
        send_button = QPushButton("Send")
        send_button.clicked.connect(self.send_message)
        input_layout.addWidget(send_button)
        
        layout.addLayout(input_layout)
        self.setLayout(layout)
        
        # Focus on input
        self.chat_input.setFocus()
    
    def center_window(self):
        """Center the window on screen"""
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def play_sound(self, filename):
        """Play sound using macOS afplay command"""
        try:
            import os
            script_dir = os.path.dirname(os.path.abspath(__file__))
            sound_path = os.path.join(script_dir, 'sound', filename)
            if os.path.exists(sound_path):
                subprocess.Popen(['afplay', sound_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"Error playing sound: {e}")
    
    def show_loading_message(self):
        """Show loading animation message"""
        self.loading_message = "💭 Thinking"
        self.loading_dots = 0
        
        # Add initial loading message
        self.add_message("AI", self.loading_message + "...", skip_sound=True)
        
        # Start animation timer
        self.loading_timer = QTimer()
        self.loading_timer.timeout.connect(self.update_loading_animation)
        self.loading_timer.start(500)  # Update every 500ms
    
    def update_loading_animation(self):
        """Update the loading dots animation"""
        self.loading_dots = (self.loading_dots + 1) % 4
        dots = "." * self.loading_dots if self.loading_dots > 0 else "..."
        loading_text = f"{self.loading_message}{dots}"
        
        # Find the last message (should be our loading message) and update it
        if self.chat_layout.count() > 1:  # At least one message plus stretch
            last_item_index = self.chat_layout.count() - 2  # -1 for stretch, -1 for 0-based
            last_item = self.chat_layout.itemAt(last_item_index)
            if last_item and last_item.widget():
                self._update_bubble_text_recursive(last_item.widget(), loading_text)
    
    def _update_bubble_text_recursive(self, widget, new_text):
        """Recursively find and update bubble text"""
        if hasattr(widget, 'setText') and hasattr(widget, 'text'):
            current_text = widget.text()
            if current_text and current_text.startswith("💭"):
                widget.setText(new_text)
                return True
        
        # Check children
        if hasattr(widget, 'children'):
            for child in widget.children():
                if hasattr(child, 'widget'):
                    child_widget = child.widget() if callable(child.widget) else None
                    if child_widget and self._update_bubble_text_recursive(child_widget, new_text):
                        return True
                elif self._update_bubble_text_recursive(child, new_text):
                    return True
        
        return False
    
    def remove_loading_message(self):
        """Remove loading message and stop animation"""
        if hasattr(self, 'loading_timer'):
            self.loading_timer.stop()
            delattr(self, 'loading_timer')
        
        # Find and remove the last message if it's a loading message
        if self.chat_layout.count() > 1:  # At least one message plus stretch
            last_item_index = self.chat_layout.count() - 2  # -1 for stretch, -1 for 0-based
            last_item = self.chat_layout.itemAt(last_item_index)
            if last_item and last_item.widget():
                container = last_item.widget()
                if self._container_has_loading_message(container):
                    self.chat_layout.removeItem(last_item)
                    container.deleteLater()
    
    def _container_has_loading_message(self, container):
        """Check if container contains the loading message"""
        return self._find_loading_bubble_recursive(container) is not None
    
    def _find_loading_bubble_recursive(self, widget):
        """Recursively find loading bubble"""
        if hasattr(widget, 'text') and hasattr(widget, 'setText'):
            current_text = widget.text()
            if current_text and current_text.startswith("💭"):
                return widget
        
        # Check children
        if hasattr(widget, 'children'):
            for child in widget.children():
                if hasattr(child, 'widget'):
                    child_widget = child.widget() if callable(child.widget) else None
                    if child_widget:
                        result = self._find_loading_bubble_recursive(child_widget)
                        if result:
                            return result
                else:
                    result = self._find_loading_bubble_recursive(child)
                    if result:
                        return result
        
        return None
    
    def send_message(self):
        """Send message to AI and display response (non-blocking)"""
        user_input = self.chat_input.text().strip()
        if not user_input:
            return
        
        # Prevent multiple simultaneous requests
        if hasattr(self, 'ai_worker') and self.ai_worker.isRunning():
            print("AI request already in progress, ignoring new request")
            return
        
        # Clear input immediately
        self.chat_input.clear()
        
        # Add user message to display immediately
        self.add_message("You", user_input)
        
        # Show loading animation immediately
        self.show_loading_message()
        
        # Disable input while processing
        self.chat_input.setEnabled(False)
        
        # Create and start background thread for AI processing
        self.ai_worker = AIWorkerThread(self.ai_service, self.ai_plugin, user_input)
        self.ai_worker.response_ready.connect(self.on_ai_response)
        self.ai_worker.error_occurred.connect(self.on_ai_error)
        self.ai_worker.finished.connect(self.on_ai_finished)
        self.ai_worker.start()
    
    def on_ai_response(self, response, commands_used):
        """Handle successful AI response"""
        # Remove loading message
        self.remove_loading_message()
        
        # Add AI response
        self.add_message("AI", response, commands_used)
    
    def on_ai_error(self, error_message):
        """Handle AI error"""
        # Remove loading message
        self.remove_loading_message()
        
        # Add error message
        self.add_message("AI", error_message)
    
    def on_ai_finished(self):
        """Called when AI processing is complete (success or error)"""
        # Re-enable input
        self.chat_input.setEnabled(True)
        
        # Focus back on input
        self.chat_input.setFocus()
        
        # Clean up worker
        if hasattr(self, 'ai_worker'):
            self.ai_worker.deleteLater()
            delattr(self, 'ai_worker')
    
    def add_message(self, sender, message, commands_used=None, skip_sound=False):
        """Add a message to the chat display with properly styled bubbles"""
        # Filter out SYSINFPULL commands from display
        if "SYSINFPULL:" in message:
            # Remove the SYSINFPULL part and any text after it
            message = message.split("SYSINFPULL:")[0].strip()
            # If there's no text left after removing SYSINFPULL, don't display anything
            if not message:
                return
        
        # Get timestamp
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M")
        
        # Remove the stretch item temporarily
        stretch_item = self.chat_layout.takeAt(self.chat_layout.count() - 1)
        
        # Create message container
        message_container = QWidget()
        container_layout = QVBoxLayout(message_container)
        container_layout.setContentsMargins(0, 0, 0, 0)
        container_layout.setSpacing(4)
        
        # Create bubble container with alignment
        bubble_container = QWidget()
        bubble_layout = QHBoxLayout(bubble_container)
        bubble_layout.setContentsMargins(0, 0, 0, 0)
        
        # Create the message bubble
        bubble = QLabel()
        bubble.setText(message)
        bubble.setWordWrap(True)
        bubble.setTextInteractionFlags(Qt.TextSelectableByMouse)
        bubble.setFont(QFont("-apple-system", 14))
        
        # Style based on sender
        if sender == "AI":
            # AI message: blue bubble, left-aligned
            if not skip_sound:
                self.play_sound('message-agent.mp3') 
            bubble.setStyleSheet("""
                QLabel {
                    background-color: #007aff;
                    color: white;
                    padding: 12px 16px;
                    border-radius: 20px;
                    margin: 6px;
                }
            """)
            bubble.setMaximumWidth(320)
            
            # Add shadow effect
            shadow = QGraphicsDropShadowEffect()
            shadow.setBlurRadius(8)
            shadow.setColor(QColor(0, 0, 0, 40))
            shadow.setOffset(0, 2)
            bubble.setGraphicsEffect(shadow)
            
            # Left align
            bubble_layout.addWidget(bubble)
            bubble_layout.addStretch()
            
            # Timestamp
            timestamp_label = QLabel(timestamp)
            timestamp_label.setStyleSheet("color: #8E8E93; font-size: 11px; margin-left: 4px;")
            timestamp_container = QWidget()
            timestamp_layout = QHBoxLayout(timestamp_container)
            timestamp_layout.setContentsMargins(4, 0, 0, 0)
            timestamp_layout.addWidget(timestamp_label)
            timestamp_layout.addStretch()
            
        else:  # User
            # User message: grey bubble, right-aligned
            if not skip_sound:
                self.play_sound('message-user.mp3') 
            bubble.setStyleSheet("""
                QLabel {
                    background-color: #E5E5EA;
                    color: black;
                    padding: 12px 16px;
                    border-radius: 20px;
                    margin: 6px;
                }
            """)
            bubble.setMaximumWidth(320)
            
            # Add shadow effect
            shadow = QGraphicsDropShadowEffect()
            shadow.setBlurRadius(8)
            shadow.setColor(QColor(0, 0, 0, 40))
            shadow.setOffset(0, 2)
            bubble.setGraphicsEffect(shadow)
            
            # Right align
            bubble_layout.addStretch()
            bubble_layout.addWidget(bubble)
            
            # Timestamp
            timestamp_label = QLabel(timestamp)
            timestamp_label.setStyleSheet("color: #8E8E93; font-size: 11px; margin-right: 4px;")
            timestamp_container = QWidget()
            timestamp_layout = QHBoxLayout(timestamp_container)
            timestamp_layout.setContentsMargins(0, 0, 4, 0)
            timestamp_layout.addStretch()
            timestamp_layout.addWidget(timestamp_label)
        
        # Add to container
        container_layout.addWidget(bubble_container)
        container_layout.addWidget(timestamp_container)
        
        # Add command indicator for AI messages
        if sender == "AI" and commands_used:
            command_indicator = QLabel(f"🔧 {commands_used}")
            command_indicator.setStyleSheet("""
                color: #8E8E93; 
                font-size: 10px; 
                font-style: italic;
                margin-left: 4px;
                padding-left: 4px;
            """)
            command_container = QWidget()
            command_layout = QHBoxLayout(command_container)
            command_layout.setContentsMargins(4, 0, 0, 0)
            command_layout.addWidget(command_indicator)
            command_layout.addStretch()
            container_layout.addWidget(command_container)
        
        # Add message to chat layout
        self.chat_layout.addWidget(message_container)
        
        # Re-add the stretch at the bottom
        self.chat_layout.addItem(stretch_item)
        
        # Auto-scroll to bottom
        QTimer.singleShot(50, lambda: self.scroll_to_bottom())
    
    def scroll_to_bottom(self):
        """Scroll to the bottom of the chat"""
        scrollbar = self.scroll_area.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())