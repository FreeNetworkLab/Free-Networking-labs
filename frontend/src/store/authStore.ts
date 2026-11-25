// ログイン状態のグローバル管理（2026-09-16決定: 状態管理はZustandを採用、設計メモ（非公開）参照）。
import { create } from 'zustand'
import { createJSONStorage, persist } from 'zustand/middleware'
import { ApiError, login as apiLogin, setAuthToken, setUnauthorizedHandler } from '../api/client'

interface AuthState {
  token: string | null
  username: string | null
  remember: boolean // このブラウザでログインを保つ（localStorage）。既定は false
  isAuthenticating: boolean
  error: string | null
  login: (username: string, password: string, remember?: boolean) => Promise<void>
  logout: () => void
}

// ログインのトークンの置き場（2026-11-18に見直し）。
// 既定は sessionStorage（タブを閉じると消える）。以前は localStorage で、ブラウザを閉じても有効期限（8時間）まで残り、
// 共有パソコンで次の人が前の人のログインのまま使えた。ログイン画面で「このブラウザでログインを保つ」を選んだ時だけ、
// localStorage に置く（自分のパソコン向け）。以前の版が localStorage に残したもの（remember が無い）は、読まずに消す
function pickStorage(remember: boolean): Storage {
  return remember ? localStorage : sessionStorage
}
export const authStorage = {
  getItem: (name: string): string | null => {
    try {
      const fromSession = sessionStorage.getItem(name)
      if (fromSession) return fromSession
      const fromLocal = localStorage.getItem(name)
      if (!fromLocal) return null
      if (JSON.parse(fromLocal)?.state?.remember === true) return fromLocal
      localStorage.removeItem(name)
    } catch {
      // 使えない環境では、ログインを保たない
    }
    return null
  },
  setItem: (name: string, value: string): void => {
    try {
      const remember = JSON.parse(value)?.state?.remember === true
      pickStorage(!remember).removeItem(name)
      pickStorage(remember).setItem(name, value)
    } catch {
      // 保存できなくても、画面は使える（再読み込みでログインが外れるだけ）
    }
  },
  removeItem: (name: string): void => {
    try {
      localStorage.removeItem(name)
      sessionStorage.removeItem(name)
    } catch {
      // 何もしない
    }
  },
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => {
      // トークン切れ(401)を検知したら自動的にログアウト状態に戻す（api-contract.mdの通りリフレッシュ手段は無い）
      setUnauthorizedHandler(() => set({ token: null, username: null, remember: false }))

      return {
        token: null,
        username: null,
        remember: false,
        isAuthenticating: false,
        error: null,
        login: async (username, password, remember = false) => {
          set({ isAuthenticating: true, error: null })
          try {
            const { token } = await apiLogin(username, password)
            setAuthToken(token)
            set({ token, username, remember, isAuthenticating: false })
          } catch (e) {
            const message = e instanceof ApiError ? e.message : 'ログインに失敗しました'
            set({ isAuthenticating: false, error: message })
            throw e
          }
        },
        logout: () => {
          setAuthToken(null)
          set({ token: null, username: null, remember: false, error: null })
        },
      }
    },
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => authStorage),
      partialize: (state) => ({ token: state.token, username: state.username, remember: state.remember }),
      onRehydrateStorage: () => (state) => {
        // sessionStorageから復元したトークンをAPIクライアントにも反映する
        if (state?.token) setAuthToken(state.token)
      },
    },
  ),
)
