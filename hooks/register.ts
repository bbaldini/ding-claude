import type { Register, EngineInterface } from 'claude-code'

const BUSY_TITLE = '⏳ Claude sta lavorando…'
const DONE_TITLE = '✅ Claude ha finito'
const BELL = '\u0007'
const osc0 = (t: string) => `\u001b]0;${t}\u0007`

type Platform = 'wsl' | 'linux' | 'mac' | 'other'

// Testo sicuro dentro una stringa PowerShell tra apici singoli.
const psQuote = (s: string) =>
  `'${s
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/["`‘’‚‛“”]/g, "'")
    .replace(/'/g, "''")}'`

const toastScript = (title: string, body: string) =>
  [
    '[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null',
    '$x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)',
    "$t = $x.GetElementsByTagName('text')",
    `$t.Item(0).AppendChild($x.CreateTextNode(${psQuote(title)})) > $null`,
    `$t.Item(1).AppendChild($x.CreateTextNode(${psQuote(body)})) > $null`,
    "$id = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe'",
    '[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($id).Show([Windows.UI.Notifications.ToastNotification]::new($x))',
  ].join('; ')

const summary = (answer: string) => {
  const line = answer
    .split('\n')
    .map(l => l.replace(/[#*`>_|]+/g, ' ').replace(/\s+/g, ' ').trim())
    .find(l => l.length > 0)
  if (!line) return 'Risposta pronta.'
  return line.length > 140 ? `${line.slice(0, 137)}…` : line
}

// Lancia un comando senza aspettarlo: la notifica non deve rallentare la sessione.
const fire = ($: EngineInterface, argv: string[]) => {
  void $.process.run(argv, { timeoutMs: 15000 }).catch(() => {})
}

// Scrive sequenze di controllo (titolo, campanella) sul terminale della sessione.
// Prima /dev/tty; se il processo non ce l'ha, risale ai processi padre fino al terminale di Claude.
const TTY_SH = [
  'if (: > /dev/tty) 2>/dev/null; then printf "%s" "$1" > /dev/tty; exit 0; fi',
  'p=$PPID',
  'while [ "${p:-1}" -gt 1 ]; do',
  '  t=$(ps -o tty= -p "$p" | tr -d " ")',
  '  case "$t" in ""|"?") ;; *) printf "%s" "$1" > "/dev/$t"; exit 0;; esac',
  '  p=$(ps -o ppid= -p "$p" | tr -d " ")',
  'done',
].join('\n')
const toTty = ($: EngineInterface, seq: string) => fire($, ['sh', '-c', TTY_SH, 'sh', seq])

export const register: Register = on => {
  let platform: Platform = 'other'

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    const m = await $.session.machine()
    if (/linux/i.test(m.sysname) && /microsoft|wsl/i.test(m.release)) platform = 'wsl'
    else if (/linux/i.test(m.sysname)) platform = 'linux'
    else if (/darwin/i.test(m.sysname)) platform = 'mac'
    return result
  })

  on('turn.start', ($, e, next) => {
    if (e.agentId === undefined && platform !== 'other') toTty($, osc0(BUSY_TITLE))
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined || e.isAborted) return result

    const title = e.reason === 'answer' ? 'Claude ha finito' : 'Claude si è fermato'
    const body = `${summary(e.answer)} (${Math.round(e.durationMs / 1000)} s)`

    if (platform === 'other') {
      // Windows nativo o piattaforma sconosciuta: canale di notifica di Claude Code.
      void $.ui.notify(body, { title }).catch(() => {})
      return result
    }

    // Titolo della scheda + campanella (icona/lampeggio della scheda e della barra delle applicazioni).
    toTty($, osc0(DONE_TITLE) + BELL)

    if (platform === 'wsl') {
      fire($, ['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', toastScript(title, body)])
    } else if (platform === 'mac') {
      fire($, ['osascript', '-e', 'on run argv', '-e', 'display notification (item 2 of argv) with title (item 1 of argv)', '-e', 'end run', title, body])
    } else {
      fire($, ['notify-send', '-a', 'Claude Code', title, body])
    }
    return result
  })
}
