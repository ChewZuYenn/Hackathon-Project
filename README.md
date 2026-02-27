# Flutter AI Tutor App 🎓

---

## 📋 Project Description

### Purpose & Problem Statement

Access to quality, personalised academic support is unequal. Students preparing for high-stakes exams — IGCSE, A-Level, SPM, and similar — often cannot afford one-to-one tutoring, and generic study apps do not adapt to individual weaknesses or explain concepts in a conversational way.

**Flutter AI Tutor** solves this by putting an intelligent, voice-enabled tutor in every student's pocket — completely free. The app:

- **Generates exam-style practice questions** dynamically, tailored to the student's chosen subject, topic, and difficulty level.
- **Listens to the student speak** and responds in natural spoken audio — replicating a real tutoring conversation.
- **Adapts the next topic** based on the student's performance history, focusing effort on areas of weakness.
- **Lets students show their working** — by typing or drawing equations freehand — and gives AI feedback on their reasoning, not just their final answer.

### Alignment with AI & the UN Sustainable Development Goals (SDGs)

| SDG | How the app contributes |
|---|---|
| **. |
| **SDG 10 — Reduced Inequalities** | Lowers barriers to academic success by making high-quality study tools free and accessible across income levels and geography. |
| **SDG 9 — Industry, Innovation & Infrastructure** | Demonstrates responsible, practical AI integration in education using state-of-the-art LLMs and on-device speech recognition. |

The core AI engine (Google Gemini) is leveraged not just for content generation, but as an interactive conversational partner — making this a frontier application of generative AI in education.

---

## 📖 Project Documentation

### Technical Implementation — Technologies Used

#### Google Technologies (Primary Stack)
| Technology | Role |
|---|---|
| **Google Gemini API** (`gemini-2.0-flash`) | Generates exam-style questions and powers the conversational AI tutor with full question + working-space context |
| **Flutter** | Cross-platform frontend for Android, iOS, and Web |
| **Firebase Authentication** | Secure user login and identity management |
| **Firebase Firestore** | Stores per-user progress, attempt history, and adaptive topic weights |
| **Google Speech-to-Text** (on-device via `speech_to_text`) | Captures the student's spoken question in real time with no cloud round-trip |
| **Google Text-to-Speech** (on-device via `flutter_tts`) | Speaks the AI tutor's response aloud when backend TTS is unavailable |

#### Supporting Technologies
| Technology | Role |
|---|---|
| **ElevenLabs TTS** | High-quality voice synthesis for the AI tutor's audio replies (via a Node.js backend proxy) |
| **Node.js / Express** | Lightweight backend proxy that securely calls external TTS APIs and returns base64-encoded MP3 audio |
| **just_audio** | Audio playback of MP3 responses from the backend |
| **shared_preferences** | Local persistence of conversation history across sessions |

---

### Implementation Overview

The app follows a clean layered architecture:

```
Student speaks
     │
     ▼
[On-device STT] ──► transcript text
     │
     ▼
[Node.js /chat] ──► Google Gemini API (with question context + working space)
     │
     ▼
AI reply text ──► [Node.js /tts] ──► ElevenLabs MP3 audio
     │
     ▼
[just_audio] plays MP3 ──► Student hears the tutor's voice
```

**Adaptive Learning Engine:** After every answered question, a weighted scoring algorithm (stored in Firestore) adjusts topic selection probability — topics with more recent failures appear more frequently, ensuring the student always practices where they need it most.

**Handwriting Canvas:** A custom `CustomPainter`-based drawing surface lets students sketch equations and diagrams with their finger, simulating paper-based exam working.

---

### Innovation Highlights

1. **Full voice loop on a mobile device** — the complete chain (speech → LLM → voice) runs with a single mic tap, with no manual text input required.
2. **Context-aware AI tutor** — Gemini receives the exact exam question AND the student's typed/drawn working, enabling feedback that references what the student has actually written (not just a generic hint).
3. **Adaptive topic selection** — the app learns which topics a student struggles with and weightedly prioritises them, making every session more effective than a fixed curriculum.
4. **Graceful degradation** — if any external API fails, the app silently falls back: backend TTS → device TTS; backend AI → error message. The student's experience is never blocked by a partial outage.

---

### Challenges Faced

| Challenge | Solution |
|---|---|
| Android `speech_to_text` fires `done` before the final recognised words arrive | Added a 500 ms delay before processing the transcript, giving Android time to deliver the final `onResult` callback |
| `just_audio` `play()` resolves before audio finishes, causing the temp file to be deleted mid-playback | Subscribe to `processingStateStream` **before** calling `play()` so the completion event is never missed |
| `FlutterTts.awaitSpeakCompletion(true)` Future never resolved on some Android builds | Replaced with a `Completer` + 30-second hard timeout, ensuring the UI always returns to idle |
| ElevenLabs API key permissions (401 error) | Re-issued a key with full `text_to_speech` permission |
| Gemini API quota exhaustion during testing | Added `MOCK_MODE=true` in backend `.env` to return instant canned responses, decoupling UI testing from API availability |

---



## 🌟 Key Features

1. **AI Question Generation**: Automatically generates personalized questions based on subject, topic, and difficulty using Gemini.
2. **Interactive Voice Tutor**: A voice loop that allows users to speak to an AI tutor.
   - **STT**: On-device speech recognition via `speech_to_text`.
   - **Intelligence**: Direct conversation with Gemini (`gemini-2.0-flash`), which is given context about the current question and the student's working space.
   - **TTS**: High-quality voice responses generated by ElevenLabs via a local Node.js backend and played using `just_audio`.
3. **Versatile Working Space**: A dedicated area where students can either type their solutions or use the **Handwriting Canvas** to draw out equations and diagrams.
4. **Progress Tracking & Firebase**: Authenticates users and stores their attempts, scores, and progress in Firebase Firestore.

---

## 🏗 System Architecture

- **Frontend**: Flutter (iOS, Android, Web). Handles UI, local speech recognition, drawing canvas, and makes direct API calls to Gemini.
- **Backend (Node.js)**: A lightweight Express server located in the `backend/` folder. It acts as a secure proxy to convert text into ElevenLabs MP3 audio via their SDK, avoiding exposing the ElevenLabs API key on the client side.

---

## ⚙️ Prerequisites

Before you begin, ensure you have the following installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10.0 or higher)
- [Node.js](https://nodejs.org/) (v16.0 or higher)
- A [Google Gemini API Key](https://aistudio.google.com/)
- An [ElevenLabs API Key & Voice ID](https://elevenlabs.io/)
- A configured Firebase project (ensure `google-services.json` / `GoogleService-Info.plist` are set up if building for mobile).

---

## 🚀 Setup Instructions

> **Quick Start Summary**
> 1. Fill in both `.env` files (Flutter root + `backend/`)
> 2. `cd backend && npm install && node server.js` ← keep this terminal open
> 3. In a new terminal: `flutter pub get && flutter run`

---

### Step 1 — Flutter Environment

1. Clone the repository and open the project folder:
   ```bash
   git clone <repo-url>
   cd hackathonproject
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Create **`hackathonproject/.env`** (Flutter root — NOT inside `backend/`):
   ```env
   # Gemini API key (used for question generation)
   GEMINI_API_KEY=your_gemini_api_key_here

   # URL of the Node.js backend
   # ▸ Android Emulator  → http://10.0.2.2:3000
   # ▸ Physical device   → http://<your-local-IP>:3000  (e.g. http://192.168.1.5:3000)
   VOICE_TUTOR_BACKEND_URL=http://10.0.2.2:3000
   ```

---

### Step 2 — Node.js Backend (AI Chat + TTS)

1. Move into the backend folder:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create **`hackathonproject/backend/.env`**:
   ```env
   # Gemini — powers the AI tutor chat
   GEMINI_API_KEY=your_gemini_api_key_here

   # ElevenLabs — high-quality voice responses
   ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
   ELEVENLABS_VOICE_ID=your_voice_id_here
   ELEVENLABS_MODEL_ID=eleven_turbo_v2

   PORT=3000

   # Set to true to bypass all external APIs during UI testing
   MOCK_MODE=false
   ```
   > ⚠️ Make sure your ElevenLabs API key has **`text_to_speech`** permission enabled in the ElevenLabs dashboard.

4. Start the backend server (**must run from inside `backend/`**):
   ```bash
   node server.js
   ```
   You should see:
   ```
   ✅  Voice Tutor backend listening on http://localhost:3000
   ```

---

### Step 3 — Run the Flutter App

Open a **new terminal** (keep the backend running), go back to the project root, and launch the app:
```bash
cd hackathonproject
flutter run
```

---

## 📁 Key File Structure

```text
hackathonproject/
├── backend/
│   ├── server.js                        # Node.js backend for ElevenLabs TTS
│   └── package.json
├── lib/
│   ├── controller/
│   │   └── voice_tutor_controller.dart  # Manages Mic, STT, Gemini chat, and TTS playback loop
│   ├── screens/
│   │   └── question_screen.dart         # Main UI for questions, workspace, and tutor
│   ├── services (API call etc)/
│   │   ├── gemini_service.dart          # Generates questions via Gemini
│   │   ├── tutor_gemini_service.dart    # Manages AI Tutor persona and direct Gemini chat
│   │   ├── voice_tutor_service.dart     # Communicates with Node.js backend for TTS audio
│   │   └── conversation_storage...      # Persists chat history locally
│   └── widgets/
│       ├── voice_tutor_panel.dart       # UI for the microphone, transcript, and AI reply
│       └── drawing_canvas.dart          # Freestyle handwriting custom painter
├── .env                                 # Flutter environment variables
└── pubspec.yaml
```

---

## 🛠 Troubleshooting

- **"Sorry, I couldn't catch that" instantly when tapping the mic:**
  Ensure you have granted microphone permissions on your device/emulator. The app includes a small warmup delay to accommodate Android emulator speech services, but requires a functional microphone.
- **Tutor gives a text response, but no audio plays:**
  1. Check if the Node.js backend is running.
  2. Verify your `VOICE_TUTOR_BACKEND_URL` in the Flutter `.env` matches your testing environment (e.g., `10.0.2.2` for emulator vs. local IP for physical devices).
  3. Ensure your `ELEVENLABS_API_KEY` has the correct `text_to_speech` permissions.
- **Firebase Initialization Errors:**
  Ensure you have properly initialized Firebase for your specific platform using the `flutterfire cli`.
