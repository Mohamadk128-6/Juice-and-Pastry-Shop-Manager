# Sweet Sip AI backend

This Firebase Function receives aggregate sales statistics only. It tries
Gemini first, then automatically falls back to Groq. Both calls have short
timeouts and run outside the Flutter sales flow.

Set the secrets without placing them in source code:

```powershell
npx firebase-tools functions:secrets:set GEMINI_API_KEY --project sweet-shop-3da48
npx firebase-tools functions:secrets:set GROQ_API_KEY --project sweet-shop-3da48
```

Then install and deploy:

```powershell
Set-Location functions
npm install
Set-Location ..
npx firebase-tools deploy --only functions,firestore:rules --project sweet-shop-3da48
```
