# ding-claude 🔔

Plugin per Claude Code (terminale) che ti avvisa quando Claude **ha finito di rispondere**, così puoi cambiare finestra mentre lavora.

Alla fine di ogni risposta:

- **Notifica di sistema** con la prima riga della risposta e la durata
  - WSL → toast di Windows (via `powershell.exe`, nessuna dipendenza)
  - Linux → `notify-send`
  - macOS → `osascript`
  - altro → il canale di notifica di Claude Code (`preferredNotifChannel` in `/config`)
- **Titolo della scheda del terminale**: `⏳ Claude sta lavorando…` durante il turno, `✅ Claude ha finito` alla fine
- **Campanella** (BEL): in Windows Terminal fa comparire l'icona 🔔 sulla scheda e lampeggiare la barra delle applicazioni
- **Badge sulla barra delle applicazioni** (WSL): sull'icona della finestra del terminale (Windows Terminal, VS Code…) compare una piccola cloche 🛎️ bianca su cerchio arancione, che sparisce quando torni sulla finestra. Se la stai già guardando quando Claude finisce, il badge non compare.

Le risposte interrotte (Esc) e i subagenti non generano notifiche.

## Installazione

Al prompt di una sessione di Claude Code nel terminale:

```
/plugin install done-notify --marketplace bbaldini/ding-claude
```

Rispondi `y` per aggiungere il marketplace, poi scegli lo scope (utente = tutte le sessioni).

Da shell:

```
claude plugin install done-notify --marketplace bbaldini/ding-claude
```

## Suggerimenti

- Windows Terminal: per il lampeggio della barra delle applicazioni imposta `"bellStyle": ["window", "taskbar"]` nel profilo.
- Se Claude Code sovrascrive il titolo della scheda, in Windows Terminal disattiva "Suppress title changes" (deve restare spento) oppure affidati a campanella e toast.
- Su Windows le notifiche arrivano a nome di "Windows PowerShell": verifica che non siano silenziate in Impostazioni → Sistema → Notifiche.

- Per provare il badge (WSL), da una shell: `powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w hooks/badge.ps1)" -Mode demo` e poi passa subito a un'altra finestra: il badge resta 8 secondi.
- Il badge non compare? Controlla in Impostazioni → Personalizzazione → Barra delle applicazioni → Comportamenti che "Mostra badge sulle app della barra delle applicazioni" sia attivo, e che la barra non usi le icone piccole.

## Licenza

MIT
