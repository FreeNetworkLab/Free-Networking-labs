// 管理者のユーザー管理画面（components/AdminUsers.tsx）の部品。画面に依存しない処理だけをここに置く（2026-11-16）。
// アカウントは clab-api-server のコンテナの中に作る（設計メモ（非公開） 2026-11-16）。
// 利用者のアカウントは常に「clab_api だけ・nologin」。管理者（clab_admins）はこの画面から作らない。

// tools/add-user.sh と同じ規則：英小文字で始まり、英小文字・数字・_・- の2〜32文字
const USERNAME_PATTERN = /^[a-z][a-z0-9_-]{1,31}$/

export function validateUsername(name: string): string | null {
  if (!USERNAME_PATTERN.test(name)) return 'ユーザー名は、英小文字で始まり、英小文字・数字・_・- の2〜32文字にしてください'
  return null
}

const LOWER = 'abcdefghijkmnopqrstuvwxyz' // 紛らわしい l を除く
const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ' // 紛らわしい I・O を除く
const DIGIT = '23456789' // 紛らわしい 0・1 を除く
const ALL = LOWER + UPPER + DIGIT

// 偏りなく選ぶ（crypto.getRandomValues を使い、範囲を超える値は捨てる）
function pick(chars: string, random: (n: number) => Uint32Array): string {
  const limit = Math.floor(0x100000000 / chars.length) * chars.length
  for (;;) {
    const v = random(1)[0]
    if (v < limit) return chars[v % chars.length]
  }
}

const defaultRandom = (n: number) => crypto.getRandomValues(new Uint32Array(n))

// 読み間違えにくい14文字。大文字・小文字・数字を最低1文字ずつ含める
export function generatePassword(random: (n: number) => Uint32Array = defaultRandom): string {
  const chars = [pick(LOWER, random), pick(UPPER, random), pick(DIGIT, random)]
  while (chars.length < 14) chars.push(pick(ALL, random))
  // 先頭が大文字・小文字・数字の順に固定されないよう、シャッフルする
  for (let i = chars.length - 1; i > 0; i--) {
    const j = Math.floor((random(1)[0] / 0x100000000) * (i + 1))
    ;[chars[i], chars[j]] = [chars[j], chars[i]]
  }
  return chars.join('')
}

// パスワードの最低の長さ（短すぎる指定を、送る前に止める）
export const MIN_PASSWORD_LENGTH = 8

export function validatePassword(pw: string): string | null {
  if (pw.length < MIN_PASSWORD_LENGTH) return `パスワードは${MIN_PASSWORD_LENGTH}文字以上にしてください`
  if (/\s/.test(pw)) return 'パスワードに空白は使えません'
  return null
}

export interface CsvRow {
  line: number
  username: string
  fullName: string
  // 3列目で個別に指定されたパスワード（空なら、共通の初期パスワードか、自動で作ったもの）
  password: string
  error: string | null
}

// 一括登録のCSV（またはタブ区切り・貼り付け）を読む。1列目＝ユーザー名、2列目＝表示名（省略可）、3列目＝初期パスワード（省略可）。
// 1行目が「ユーザー名」「username」などの見出しなら飛ばす。空行・#で始まる行も飛ばす。重複は2つ目からエラー
export function parseUserCsv(text: string): CsvRow[] {
  const rows: CsvRow[] = []
  const seen = new Set<string>()
  const lines = text.replace(/^﻿/, '').split(/\r?\n/)
  lines.forEach((raw, i) => {
    const lineText = raw.trim()
    if (!lineText || lineText.startsWith('#')) return
    const cells = lineText.split(/[,\t]/).map((c) => c.trim().replace(/^"(.*)"$/, '$1'))
    if (rows.length === 0 && /^(username|user|ユーザー名|ユーザー)$/i.test(cells[0])) return
    const username = cells[0] ?? ''
    const fullName = cells[1] ?? ''
    const password = cells[2] ?? ''
    let error = validateUsername(username)
    if (!error && seen.has(username)) error = 'ユーザー名が重複しています'
    if (!error && password) error = validatePassword(password)
    seen.add(username)
    rows.push({ line: i + 1, username, fullName, password, error })
  })
  return rows
}

export interface CreatedAccount {
  username: string
  password: string
  result: string
}

// 結果をCSVにする（表計算ソフトで開ける。先頭にBOMは付けない代わりに、呼ぶ側がBOMを付けて保存する）。
// セルに , " 改行 があれば引用符で囲む。先頭が = + - @ のセルは、表計算ソフトが式と読まないよう ' を付ける
export function accountsToCsv(accounts: CreatedAccount[]): string {
  const cell = (v: string) => {
    const safe = /^[=+\-@]/.test(v) ? `'${v}` : v
    return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe
  }
  const lines = [['ユーザー名', 'パスワード', '結果'].join(',')]
  for (const a of accounts) lines.push([a.username, a.password, a.result].map(cell).join(','))
  return lines.join('\r\n') + '\r\n'
}
