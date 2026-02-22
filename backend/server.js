/**
 * Voice Tutor Backend
 * Endpoints:
 *   POST /voice-turn  – audio → transcript → AI reply → TTS audio (all-in-one)
 *   POST /stt         – audio bytes → transcript text
 *   POST /chat        – transcript + history → AI reply text
 *   POST /tts         – text → MP3 bytes (base64)
 *
 * Run: node server.js
 * Requires: .env with OPENAI_API_KEY, GEMINI_API_KEY, ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID
 */

require('dotenv').config();
const express = require('express');
const multer = require('multer');
const fetch = require('node-fetch');
const FormData = require('form-data');

const app = express();
app.use(express.json({ limit: '10mb' }));

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 25 * 1024 * 1024 } });

// ── ENV validation ──────────────────────────────────────────────────────────
const REQUIRED_VARS = ['GEMINI_API_KEY', 'ELEVENLABS_API_KEY', 'ELEVENLABS_VOICE_ID'];
const missing = REQUIRED_VARS.filter(v => !process.env[v]);
if (missing.length) {
  console.error(`❌  Missing env vars: ${missing.join(', ')}`);
  process.exit(1);
}

// Optional: OPENAI_API_KEY is needed for Whisper STT; fall back to Gemini if absent.
const USE_WHISPER_STT = !!process.env.OPENAI_API_KEY;
console.log(`STT backend: ${USE_WHISPER_STT ? 'OpenAI Whisper' : 'Gemini (no OPENAI_API_KEY set)'}`);

// ── Helpers ─────────────────────────────────────────────────────────────────

/** OpenAI Whisper STT */
async function transcribeWithWhisper(audioBuffer, mimeType) {
  const form = new FormData();
  form.append('file', audioBuffer, { filename: 'audio.m4a', contentType: mimeType || 'audio/m4a' });
  form.append('model', 'whisper-1');
  form.append('language', 'en');

  const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
      ...form.getHeaders(),
    },
    body: form,
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Whisper STT failed (${res.status}): ${err}`);
  }
  const data = await res.json();
  return data.text?.trim() ?? '';
}

/** Gemini chat – returns the full reply text */
async function chatWithGemini(userText, history, examContext, questionText, workingSpace) {
  const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${process.env.GEMINI_API_KEY}`;

  const contents = [];

  // Build a rich system prompt with full context about what the student is working on
  let systemPrompt = `You are a friendly, encouraging voice AI tutor helping a student with ${examContext?.examType ?? 'their exam'} – ${examContext?.subject ?? 'general studies'}, topic: ${examContext?.topic ?? 'any topic'}.`;

  if (questionText && questionText.trim()) {
    systemPrompt += `\n\nThe student is currently working on this question:\n"${questionText.trim()}"`;
  }

  if (workingSpace && workingSpace.trim()) {
    systemPrompt += `\n\nThe student's working space (their notes and calculations so far) shows:\n"${workingSpace.trim()}"`;
  }

  systemPrompt += `\n\nBe helpful, concise (2-4 sentences), and encouraging. If the student has working shown, reference it in your response. Use clear, simple language. Never use markdown, bullet points, or special symbols – plain prose only, since your response will be spoken aloud.`;

  contents.push({ role: 'user', parts: [{ text: systemPrompt }] });
  contents.push({ role: 'model', parts: [{ text: "Got it! I'm ready to help this student." }] });

  // Inject history
  for (const turn of history) {
    contents.push({ role: 'user', parts: [{ text: turn.user }] });
    contents.push({ role: 'model', parts: [{ text: turn.assistant }] });
  }

  contents.push({ role: 'user', parts: [{ text: userText }] });

  const body = {
    contents,
    generationConfig: { temperature: 0.7, maxOutputTokens: 300, topP: 0.95 },
    safetySettings: [
      { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
    ],
  };

  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini chat failed (${res.status}): ${err}`);
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
  if (!text) throw new Error('Empty response from Gemini');
  return text.trim();
}

/** ElevenLabs TTS – returns Buffer of MP3 bytes */
async function synthesizeWithElevenLabs(text) {
  const voiceId = process.env.ELEVENLABS_VOICE_ID;
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'xi-api-key': process.env.ELEVENLABS_API_KEY,
      'Content-Type': 'application/json',
      'Accept': 'audio/mpeg',
    },
    body: JSON.stringify({
      text,
      model_id: process.env.ELEVENLABS_MODEL_ID || 'eleven_turbo_v2',
      voice_settings: { stability: 0.5, similarity_boost: 0.75 },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`ElevenLabs TTS failed (${res.status}): ${err}`);
  }

  return Buffer.from(await res.arrayBuffer());
}

// ── Routes ───────────────────────────────────────────────────────────────────

/** Health check */
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

/**
 * POST /stt
 * Body: multipart/form-data  { audio: <file>, mimeType?: string }
 * Returns: { transcript: string }
 */
app.post('/stt', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No audio file uploaded' });
    const mimeType = req.body.mimeType || req.file.mimetype || 'audio/m4a';

    let transcript;
    if (USE_WHISPER_STT) {
      transcript = await transcribeWithWhisper(req.file.buffer, mimeType);
    } else {
      // Gemini multimodal STT fallback (send audio as inline base64)
      transcript = await transcribeWithGeminiFallback(req.file.buffer, mimeType);
    }

    res.json({ transcript });
  } catch (err) {
    console.error('[/stt]', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /chat
 * Body: { userText, history, examContext, questionText?, workingSpace? }
 * Returns: { replyText: string }
 */
app.post('/chat', async (req, res) => {
  try {
    const { userText, history = [], examContext = {}, questionText = '', workingSpace = '' } = req.body;
    if (!userText) return res.status(400).json({ error: 'userText is required' });

    console.log(`[/chat] user: "${userText.substring(0, 60)}…"  workingSpace: ${workingSpace ? `"${workingSpace.substring(0, 40)}…"` : '(none)'}`);

    const replyText = await chatWithGemini(userText, history, examContext, questionText, workingSpace);
    res.json({ replyText });
  } catch (err) {
    console.error('[/chat]', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /tts
 * Body: { text: string }
 * Returns: { audioBase64: string }   (base64-encoded MP3)
 */
app.post('/tts', async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'text is required' });

    const mp3Buffer = await synthesizeWithElevenLabs(text);
    res.json({ audioBase64: mp3Buffer.toString('base64') });
  } catch (err) {
    console.error('[/tts]', err.message);
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /voice-turn   ← PRIMARY ENDPOINT used by the Flutter app
 * Body: multipart/form-data {
 *   audio: <file>,
 *   mimeType?: string,
 *   history?: JSON string of [{user, assistant}],
 *   examContext?: JSON string of {examType, subject, topic}
 * }
 * Returns: { transcript, replyText, audioBase64 }
 */
app.post('/voice-turn', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No audio file uploaded' });

    const mimeType = req.body.mimeType || req.file.mimetype || 'audio/m4a';
    const history = JSON.parse(req.body.history || '[]');
    const examContext = JSON.parse(req.body.examContext || '{}');

    console.log(`[/voice-turn] audio=${req.file.size}B  history=${history.length} turns`);

    // Step 1: STT
    let transcript;
    if (USE_WHISPER_STT) {
      transcript = await transcribeWithWhisper(req.file.buffer, mimeType);
    } else {
      transcript = await transcribeWithGeminiFallback(req.file.buffer, mimeType);
    }
    console.log(`[/voice-turn] transcript: "${transcript}"`);

    if (!transcript) {
      return res.json({ transcript: '', replyText: "Sorry, I couldn't catch that. Could you try again?", audioBase64: '' });
    }

    // Step 2: AI chat
    const replyText = await chatWithGemini(transcript, history, examContext);
    console.log(`[/voice-turn] reply: "${replyText}"`);

    // Step 3: TTS
    const mp3Buffer = await synthesizeWithElevenLabs(replyText);

    res.json({
      transcript,
      replyText,
      audioBase64: mp3Buffer.toString('base64'),
    });
  } catch (err) {
    console.error('[/voice-turn]', err.message);
    res.status(500).json({ error: err.message });
  }
});

/** Gemini multimodal STT fallback (when no OpenAI key) */
async function transcribeWithGeminiFallback(audioBuffer, mimeType) {
  const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${process.env.GEMINI_API_KEY}`;
  const base64Audio = audioBuffer.toString('base64');

  // Normalize MIME type: audio/m4a is non-standard.
  // The recorder uses AAC-LC codec in m4a container, so use audio/aac.
  let normalizedMime = mimeType;
  if (mimeType === 'audio/m4a' || mimeType === 'audio/x-m4a' || mimeType === 'audio/mp4') {
    normalizedMime = 'audio/aac';
  }
  console.log(`[STT-Gemini] Audio size: ${audioBuffer.length}B, MIME: ${normalizedMime} (original: ${mimeType})`);

  const body = {
    contents: [{
      parts: [
        {
          text: 'Transcribe the following audio recording into text. Output ONLY the exact words spoken, with no additional commentary or formatting. If no speech is detected, output exactly: EMPTY'
        },
        { inlineData: { mimeType: normalizedMime, data: base64Audio } },
      ],
    }],
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 500,
    },
  };

  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error(`[STT-Gemini] API error (${res.status}): ${err}`);
    throw new Error(`Gemini STT fallback failed (${res.status}): ${err}`);
  }
  const data = await res.json();

  // Log the full response for debugging
  console.log(`[STT-Gemini] Full response:`, JSON.stringify(data, null, 2));

  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
  console.log(`[STT-Gemini] Extracted text: "${text}"`);

  // If Gemini returned our sentinel value, treat as empty
  if (text === 'EMPTY') return '';
  return text;
}

// ── Start ────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`✅  Voice Tutor backend listening on http://localhost:${PORT}`);
  console.log(`    POST /voice-turn  (primary – all-in-one)`);
  console.log(`    POST /stt         (audio → transcript)`);
  console.log(`    POST /chat        (text → AI reply)`);
  console.log(`    POST /tts         (text → MP3 base64)`);
});