import { useState } from 'react'
import { changeOwnPassword } from '../api/client'
import { validatePassword } from '../utils/adminUsers'
import { errorMessage } from '../utils/labRuntime'
import { useAuthStore } from '../store/authStore'
import './ChangePasswordDialog.css'

// 自分のパスワードを変えるダイアログ（2026-11-16）。管理者から配られた一時的なパスワードを、
// 初回のログイン後に自分のものへ変えるために使う。clab-api-server の PUT /api/v1/users/<自分>/password
// （現在のパスワードが要る。他人のパスワードは変えられない）
export default function ChangePasswordDialog({ onClose }: { onClose: () => void }) {
  const username = useAuthStore((s) => s.username) ?? ''
  const [current, setCurrent] = useState('')
  const [next, setNext] = useState('')
  const [again, setAgain] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)
  const [working, setWorking] = useState(false)

  const onSubmit = async (event: React.FormEvent) => {
    event.preventDefault()
    const problem = validatePassword(next)
    if (problem) return setError(problem)
    if (next !== again) return setError('新しいパスワードが、2回で一致しません')
    if (next === current) return setError('今のパスワードと、同じものは使えません')
    setWorking(true)
    try {
      await changeOwnPassword(username, current, next)
      setDone(true)
      setError(null)
    } catch (e) {
      setError(errorMessage(e, '変更できませんでした'))
    }
    setWorking(false)
  }

  return (
    <div className="topology-editor__modal-overlay" onClick={working ? undefined : onClose}>
      <div className="topology-editor__modal change-password" onClick={(e) => e.stopPropagation()}>
        <h3>パスワードの変更</h3>
        {done ? (
          <>
            <p className="change-password__ok">パスワードを変更しました。次回のログインから、新しいパスワードを使います。</p>
            <div className="change-password__actions">
              <button className="btn-primary" onClick={onClose}>
                閉じる
              </button>
            </div>
          </>
        ) : (
          <form onSubmit={onSubmit}>
            <label>
              今のパスワード
              <input type="password" value={current} onChange={(e) => setCurrent(e.target.value)} autoComplete="current-password" required />
            </label>
            <label>
              新しいパスワード（8文字以上）
              <input type="password" value={next} onChange={(e) => setNext(e.target.value)} autoComplete="new-password" required />
            </label>
            <label>
              新しいパスワード（もう一度）
              <input type="password" value={again} onChange={(e) => setAgain(e.target.value)} autoComplete="new-password" required />
            </label>
            {error && <div className="topology-editor__modal-warn">{error}</div>}
            <div className="change-password__actions">
              <button type="button" onClick={onClose} disabled={working}>
                キャンセル
              </button>
              <button className="btn-primary" type="submit" disabled={working}>
                変更する
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
