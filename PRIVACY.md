# Verba Privacy Policy

_Last updated: May 6, 2026_

Verba is built around a simple promise: your voice never leaves your phone. This document explains what that means in practice, what the app does, what it doesn't do, and what happens to the small amount of information that does leave your device.

If anything below is unclear or you have questions, you can reach the developer at **asingh3206@gatech.edu**.

---

## What Verba does

Verba is an iOS app for practicing impromptu speaking. You select a category, get a prompt, talk for up to a couple of minutes, and receive structured feedback. Your sessions, scores, and history are kept on your device.

## What stays on your device

- **Your audio.** Recorded audio is never uploaded, transmitted, or stored on any server. It exists only on your phone.
- **Speech recognition.** Speech is transcribed on-device using Apple's built-in speech recognition framework (`SFSpeechRecognizer`). The audio does not leave the device for transcription.
- **Your sessions.** Past prompts, transcripts, scores, and feedback are stored locally using Apple's SwiftData framework. They are not synced to any cloud service.
- **Your settings and preferences.** Stored locally in iOS user defaults.

If you delete the Verba app, all of this data is removed from your device.

## What leaves your device

When you finish a practice session and request feedback, Verba sends the **text of your transcript** (along with the prompt, the duration of the session, your filler-word count, and your words-per-minute) to a backend server operated by the developer. The backend immediately forwards this text to Anthropic, the provider of the Claude AI model that generates feedback. The feedback is returned to your device.

**This text is not stored on Verba's backend.** The server receives it, forwards it to Anthropic, returns the result, and discards it. No transcripts, prompts, or feedback are written to any database, log, or persistent storage.

## What the backend stores

The Verba backend stores only:

- **An anonymous device identifier.** A random UUID generated when you first launch the app. It is not linked to your name, email, Apple ID, or any other personal information.
- **A daily counter** of how many feedback requests that device identifier has made. This is used solely to enforce a per-device daily rate limit.
- **A daily counter** of total feedback requests across all users, used to enforce a global rate limit and protect operating costs.

Both counters automatically expire after 24 hours.

The backend does **not** store transcripts, audio, prompts, feedback, IP addresses, locations, device models, or any other identifying information.

## What Anthropic does with your transcripts

When the backend forwards your transcript to Anthropic for feedback generation, Anthropic processes it under its commercial API terms. Per those terms, transcripts submitted via the API are not used to train Anthropic's models. Anthropic's privacy practices are governed by their own privacy policy at https://www.anthropic.com/legal/privacy.

## What Verba does **not** do

- Verba does **not** require an account, login, or sign-in.
- Verba does **not** collect your name, email address, Apple ID, contacts, location, or any other personally identifying information.
- Verba does **not** include third-party analytics, advertising, or tracking SDKs.
- Verba does **not** sell, rent, or share any data with third parties beyond the single use of forwarding transcripts to Anthropic for feedback generation.
- Verba does **not** track you across other apps or websites.

## Permissions Verba requests

- **Microphone access**, so you can record practice sessions.
- **Speech recognition**, so your speech can be transcribed on-device.

You can revoke either permission at any time in iOS Settings under Verba.

## Children

Verba is not directed to children under 13 and does not knowingly collect any information from them. The app contains no content rated above 4+.

## Changes to this policy

If this policy changes, the updated version will be posted at the same URL where you found this one, and the "Last updated" date at the top will be revised. Material changes will also be reflected in a release note in the App Store.

## Contact

Questions, concerns, or requests can be sent to **asingh3206@gatech.edu**.
