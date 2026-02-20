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
const multer  = require('multer');
const fetch   = require('node-fetch');
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

/** Gemini chat – streams the full reply text */
async function chatWithGemini(userText, history, examContext) {
  const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${process.env.GEMINI_API_KEY}`;

  // Build conversation turns
  const contents = [];

  // System-level preamble injected as the first user turn
  const systemPrompt = `You are a friendly, encouraging voice tutor helping a student with ${examContext?.examType ?? 'their exam'} – ${examContext?.subject ?? 'general studies'}, topic: ${examContext?.topic ?? 'any topic'}.
Keep answers concise (2-4 sentences max) because they will be spoken aloud. Use clear, simple language. If the student seems confused, offer a different explanation. Never use markdown, bullet points, or special symbols – plain prose only.`;

  contents.push({ role: 'user',  parts: [{ text: systemPrompt }] });
  contents.push({ role: 'model', parts: [{ text: "Got it! I'm ready to help." }] });

  // Inject history (last N turns)
  for (const turn of history) {
    contents.push({ role: 'user',  parts: [{ text: turn.user }] });
    contents.push({ role: 'model', parts: [{ text: turn.assistant }] });
  }

  // Current user message
  contents.push({ role: 'user', parts: [{ text: userText }] });

  const body = {
    contents,
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 300,
      topP: 0.95,
    },
    safetySettings: [
      { category: 'HARM_CATEGORY_HARASSMENT',        threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_HATE_SPEECH',        threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',  threshold: 'BLOCK_NONE' },
      { category: 'HARM_CATEGORY_DANGEROUS_CONTENT',  threshold: 'BLOCK_NONE' },
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
 * Body: { userText, history: [{user, assistant}], examContext: {examType, subject, topic} }
 * Returns: { replyText: string }
 */
app.post('/chat', async (req, res) => {
  try {
    const { userText, history = [], examContext = {} } = req.body;
    if (!userText) return res.status(400).json({ error: 'userText is required' });

    const replyText = await chatWithGemini(userText, history, examContext);
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

    const mimeType   = req.body.mimeType   || req.file.mimetype || 'audio/m4a';
    const history    = JSON.parse(req.body.history    || '[]');
    const examContext= JSON.parse(req.body.examContext || '{}');

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
  const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${process.env.GEMINI_API_KEY}`;
  const base64Audio = audioBuffer.toString('base64');

  const body = {
    contents: [{
      parts: [
        { text: 'Please transcribe the speech in this audio file. Return only the transcribed text, nothing else.' },
        { inlineData: { mimeType, data: base64Audio } },
      ],
    }],
  };

  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini STT fallback failed (${res.status}): ${err}`);
  }
  const data = await res.json();
  return data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
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