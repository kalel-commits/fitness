# Fitness App

An AI-powered fitness application with a Python backend and Flutter mobile app.

## Project Structure

```
fitness/
├── main.py              # Main Python application entry point
├── llm.py               # LLM integration for AI features
├── requirements.txt     # Python dependencies
└── ai_fitness_app/      # Flutter mobile application
    ├── lib/             # Dart source code
    ├── android/         # Android platform files
    ├── ios/             # iOS platform files
    └── ...
```

## Setup

### Python Backend

1. Create a virtual environment:
```bash
python -m venv venv
```

2. Activate the virtual environment:
```bash
# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Run the backend:
```bash
python main.py
```

### Flutter App

1. Navigate to the Flutter app directory:
```bash
cd ai_fitness_app
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Features

- AI-powered workout planning
- Goal setting and tracking
- Workout routines
- Progress reports
- Premium features

## Requirements

- Python 3.8+
- Flutter 3.0+
- Dart 3.0+

## License

MIT License