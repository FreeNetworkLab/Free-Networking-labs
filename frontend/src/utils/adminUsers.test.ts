import { describe, expect, it } from 'vitest'
import { accountsToCsv, generatePassword, parseUserCsv, validatePassword, validateUsername } from './adminUsers'

describe('ユーザー名の検査', () => {
  it('add-user.sh と同じ規則', () => {
    expect(validateUsername('taro')).toBeNull()
    expect(validateUsername('student-01')).toBeNull()
    expect(validateUsername('a')).not.toBeNull() // 1文字
    expect(validateUsername('Taro')).not.toBeNull() // 大文字
    expect(validateUsername('1taro')).not.toBeNull() // 数字始まり
    expect(validateUsername('ta ro')).not.toBeNull()
    expect(validateUsername('a'.repeat(33))).not.toBeNull()
  })
})

describe('パスワードの生成', () => {
  it('14文字で、大文字・小文字・数字を含み、紛らわしい文字を使わない', () => {
    for (let i = 0; i < 200; i++) {
      const pw = generatePassword()
      expect(pw).toHaveLength(14)
      expect(pw).toMatch(/[a-z]/)
      expect(pw).toMatch(/[A-Z]/)
      expect(pw).toMatch(/[0-9]/)
      expect(pw).not.toMatch(/[lIO01]/)
    }
  })
  it('毎回違う値になる', () => {
    expect(new Set(Array.from({ length: 50 }, () => generatePassword())).size).toBe(50)
  })
  it('乱数が偏って上限を超える値は捨てる（無限ループにならない）', () => {
    let n = 0
    const seq = [0xffffffff, 0xffffffff, 5]
    const random = (k: number) => new Uint32Array(k).fill(n < seq.length ? seq[n++] : 7)
    expect(generatePassword(random)).toHaveLength(14)
  })
})

describe('一括登録のCSV', () => {
  it('見出し・空行・コメントを飛ばし、ユーザー名と表示名を読む', () => {
    const rows = parseUserCsv('﻿ユーザー名,表示名\r\nstudent01,山田 太郎\n\n# 欠席\nstudent02\n')
    expect(rows.map((r) => [r.username, r.fullName, r.error])).toEqual([
      ['student01', '山田 太郎', null],
      ['student02', '', null],
    ])
    expect(rows[1].line).toBe(5)
  })
  it('タブ区切りも読める（表計算ソフトからの貼り付け）', () => {
    expect(parseUserCsv('taro\tTaro Y').map((r) => [r.username, r.fullName])).toEqual([['taro', 'Taro Y']])
  })
  it('不正な名前と重複をエラーにする', () => {
    const rows = parseUserCsv('Taro\nhanako\nhanako\n')
    expect(rows.map((r) => r.error !== null)).toEqual([true, false, true])
    expect(rows[2].error).toContain('重複')
  })
  it('引用符で囲まれたセルを読む', () => {
    expect(parseUserCsv('"taro","Y T"')[0].fullName).toBe('Y T')
  })
})

describe('結果のCSV', () => {
  it('見出しと行を作り、特殊な文字を囲む', () => {
    expect(accountsToCsv([{ username: 'taro', password: 'Ab3,"x', result: '作成しました' }])).toBe(
      'ユーザー名,パスワード,結果\r\ntaro,"Ab3,""x",作成しました\r\n',
    )
  })
  it('式と読まれる先頭の文字には引用符を付ける', () => {
    expect(accountsToCsv([{ username: 'u1', password: '=cmd', result: '-1' }])).toContain("u1,'=cmd,'-1")
  })
})

describe('初期パスワードの指定', () => {
  it('8文字以上・空白なし', () => {
    expect(validatePassword('abcd1234')).toBeNull()
    expect(validatePassword('short')).not.toBeNull()
    expect(validatePassword('has space1')).not.toBeNull()
  })
  it('CSVの3列目で個別に指定でき、短いものはエラーにする', () => {
    const rows = parseUserCsv('taro,Taro,Passw0rd!\nhanako,,short\njiro')
    expect(rows.map((r) => [r.username, r.password, r.error !== null])).toEqual([
      ['taro', 'Passw0rd!', false],
      ['hanako', 'short', true],
      ['jiro', '', false],
    ])
  })
})
