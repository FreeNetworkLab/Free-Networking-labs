import { beforeEach, describe, expect, it, vi } from 'vitest'

function fakeStorage() {
  const m = new Map<string, string>()
  return {
    getItem: (k: string) => m.get(k) ?? null,
    setItem: (k: string, v: string) => void m.set(k, v),
    removeItem: (k: string) => void m.delete(k),
  }
}

const value = (remember?: boolean) => JSON.stringify({ state: { token: 't', username: 'u', ...(remember === undefined ? {} : { remember }) }, version: 0 })

describe('authStorage（ログインの置き場）', () => {
  let local: ReturnType<typeof fakeStorage>
  let session: ReturnType<typeof fakeStorage>
  let authStorage: (typeof import('./authStore'))['authStorage']
  beforeEach(async () => {
    local = fakeStorage()
    session = fakeStorage()
    vi.stubGlobal('localStorage', local)
    vi.stubGlobal('sessionStorage', session)
    ;({ authStorage } = await import('./authStore'))
  })

  it('既定（remember なし/false）は sessionStorage に置き、localStorage には置かない', () => {
    authStorage.setItem('k', value(false))
    expect(session.getItem('k')).not.toBeNull()
    expect(local.getItem('k')).toBeNull()
    expect(authStorage.getItem('k')).toBe(value(false))
  })

  it('remember=true は localStorage に置き、sessionStorage からは消す', () => {
    session.setItem('k', value(false))
    authStorage.setItem('k', value(true))
    expect(local.getItem('k')).toBe(value(true))
    expect(session.getItem('k')).toBeNull()
    expect(authStorage.getItem('k')).toBe(value(true))
  })

  it('以前の版が localStorage に残したもの（remember なし）は、読まずに消す', () => {
    local.setItem('k', value())
    expect(authStorage.getItem('k')).toBeNull()
    expect(local.getItem('k')).toBeNull()
  })

  it('removeItem は両方から消す', () => {
    local.setItem('k', value(true))
    session.setItem('k', value(false))
    authStorage.removeItem('k')
    expect(local.getItem('k')).toBeNull()
    expect(session.getItem('k')).toBeNull()
  })
})
