#\!/bin/bash
echo "Starting TOME log monitor..."
echo "Look for lines with 🔧 emoji for AI integration debug info"
log stream --predicate "subsystem contains \"com.tome\" OR processImagePath contains \"TOME\"" --level debug --color always | grep -E "(🔧|TOME|AI|terminal|IDE)"
