import { useCallback, useEffect, useState } from 'react'
import { changeUserPassword, createUser, deleteLab, deleteUser, getLabs, listUsers, setUserSuperuser, type ApiUser } from '../api/client'
import { purgeUserLabs } from '../api/ovsHelperClient'
import { accountsToCsv, generatePassword, parseUserCsv, validatePassword, validateUsername, type CreatedAccount } from '../utils/adminUsers'
import { errorMessage } from '../utils/labRuntime'
import { useAuthStore } from '../store/authStore'
import './AdminUsers.css'

// 管理者（clab_admins）だけのユーザー管理画面（2026-11-16）。clab-api-server の /api/v1/users を使う。
// 作るのは常に「clab_api だけ・nologin」の利用者。パスワードはこの画面で作り、結果の表に1回だけ出す
// （サーバーには平文を残さない。控えを失ったら「パスワード再設定」で作り直す）。
// 配った一時的なパスワードは、利用者が自分で変える（ナビの鍵のボタン、components/ChangePasswordDialog.tsx）。

function downloadCsv(fileName: string, text: string) {
  // 日本語の表計算ソフトで文字化けしないよう、先頭にBOMを付ける
  const url = URL.createObjectURL(new Blob(['﻿', text], { type: 'text/csv;charset=utf-8' }))
  const a = document.createElement('a')
  a.href = url
  a.download = fileName
  a.click()
  URL.revokeObjectURL(url)
}

export default function AdminUsers() {
  const me = useAuthStore((s) => s.username)
  const [users, setUsers] = useState<ApiUser[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [username, setUsername] = useState('')
  const [fullName, setFullName] = useState('')
  const [csvText, setCsvText] = useState('')
  // 全員に同じ初期パスワードを配りたい時の指定（任意）。CSVの3列目の個別の指定が優先
  const [commonPw, setCommonPw] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  // 消すときに、その人のラボと保存データも消すか。既定はオン（残すと、同じuidの新しい人に見えるおそれがある）
  const [purgeLabs, setPurgeLabs] = useState(true)
  // 作成・再設定の結果（パスワードを含む）。閉じると二度と見られない
  const [results, setResults] = useState<CreatedAccount[] | null>(null)

  const reload = useCallback(async () => {
    try {
      const all = await listUsers()
      setUsers(all.filter((u) => u.isApiUser || u.isSuperuser).sort((a, b) => a.username.localeCompare(b.username)))
      setError(null)
    } catch (e) {
      setError(errorMessage(e, '失敗しました'))
    }
  }, [])
  useEffect(() => {
    void reload()
  }, [reload])
  // パスワードを含む結果が出ている間に、ページを閉じる・更新しようとしたら確認する（保存し忘れ・控え忘れの防止）
  useEffect(() => {
    if (!results?.some((r) => r.password)) return
    const guard = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener('beforeunload', guard)
    return () => window.removeEventListener('beforeunload', guard)
  }, [results])

  const createMany = async (rows: { username: string; fullName: string; password?: string }[]) => {
    setBusy(true)
    const out: CreatedAccount[] = []
    for (const r of rows) {
      const password = r.password || generatePassword()
      try {
        await createUser(r.username, password, r.fullName || undefined)
        out.push({ username: r.username, password, result: '作成しました' })
      } catch (e) {
        out.push({ username: r.username, password: '', result: `失敗：${errorMessage(e, '失敗しました')}` })
      }
    }
    setResults(out)
    await reload()
    setBusy(false)
  }

  const onAdd = async (event: React.FormEvent) => {
    event.preventDefault()
    const name = username.trim()
    const problem = validateUsername(name)
    if (problem) {
      setError(problem)
      return
    }
    await createMany([{ username: name, fullName: fullName.trim() }])
    setUsername('')
    setFullName('')
  }

  const csvRows = parseUserCsv(csvText)
  const csvOk = csvRows.filter((r) => !r.error)
  const csvBad = csvRows.filter((r) => r.error)
  const onCsvFile = async (file: File | undefined) => {
    if (file) setCsvText(await file.text())
  }
  const commonPwProblem = commonPw ? validatePassword(commonPw) : null
  const specifiedCount = csvOk.filter((r) => r.password || commonPw).length
  const onImport = async () => {
    if (csvBad.length > 0 || csvOk.length === 0 || commonPwProblem) return
    await createMany(csvOk.map((r) => ({ username: r.username, fullName: r.fullName, password: r.password || commonPw })))
    setCsvText('')
  }

  const onReset = async (u: ApiUser) => {
    if (!window.confirm(`${u.username} のパスワードを作り直します。今のパスワードでは入れなくなります。よろしいですか？`)) return
    setBusy(true)
    const password = generatePassword()
    try {
      await changeUserPassword(u.username, password)
      setResults([{ username: u.username, password, result: 'パスワードを作り直しました' }])
    } catch (e) {
      setError(errorMessage(e, '失敗しました'))
    }
    setBusy(false)
  }

  const onResetSelected = async () => {
    const names = [...selected]
    if (names.length === 0) return
    if (!window.confirm(`選んだ ${names.length} 人のパスワードを作り直します。今のパスワードでは入れなくなります。よろしいですか？`)) return
    setBusy(true)
    const out: CreatedAccount[] = []
    for (const name of names) {
      const password = generatePassword()
      try {
        await changeUserPassword(name, password)
        out.push({ username: name, password, result: 'パスワードを作り直しました' })
      } catch (e) {
        out.push({ username: name, password: '', result: `失敗：${errorMessage(e, '失敗しました')}` })
      }
    }
    setResults(out)
    setSelected(new Set())
    setBusy(false)
  }

  const toggle = (name: string) =>
    setSelected((prev) => {
      const next = new Set(prev)
      if (!next.delete(name)) next.add(name)
      return next
    })

  // 管理者にする／やめる。自分は外せない。管理者が1人のときも外せない（管理者がいなくなるのを防ぐ）
  const onSetAdmin = async (u: ApiUser, makeAdmin: boolean) => {
    const adminCount = (users ?? []).filter((x) => x.isSuperuser).length
    if (!makeAdmin && (u.username === me || adminCount < 2)) return
    const msg = makeAdmin
      ? `${u.username} を管理者にします。ユーザーの追加・削除・パスワードの再設定、管理者の変更ができるようになります。よろしいですか？`
      : `${u.username} を管理者からはずします（利用者に戻ります）。よろしいですか？`
    if (!window.confirm(msg)) return
    setBusy(true)
    try {
      await setUserSuperuser(u.username, makeAdmin)
      await reload()
    } catch (e) {
      setError(errorMessage(e, '失敗しました'))
    }
    setBusy(false)
  }

  const onDelete = async (u: ApiUser) => {
    setBusy(true)
    try {
      // 動いているラボ（その人が持ち主のもの）を数える。管理者には全員分のラボが見える
      const labs = purgeLabs ? await getLabs() : {}
      const labNames = Object.entries(labs)
        .filter(([, nodes]) => nodes.some((n) => n.owner === u.username))
        .map(([name]) => name)
      const message = purgeLabs
        ? `${u.username} を削除します。ログインできなくなります。\n動いているラボ ${labNames.length} 個を止めて消し、保存されているラボのデータもすべて消します。元には戻せません。\nよろしいですか？`
        : `${u.username} を削除します。ログインできなくなります。\nラボのフォルダは残ります（ほかの人に見えるおそれがあるので、通常は「ラボも消す」を選んでください）。動いているラボは、止まりません。\nよろしいですか？`
      if (!window.confirm(message)) {
        setBusy(false)
        return
      }
      if (purgeLabs) {
        for (const name of labNames) await deleteLab(name)
        // まだ動いているラボが残っていたら、ここで止める（フォルダを消すと、動いているコンテナが壊れるため）
        const after = await getLabs()
        if (Object.values(after).some((nodes) => nodes.some((n) => n.owner === u.username))) {
          throw new Error('動いているラボを止められませんでした。ユーザーは、まだ削除していません')
        }
        await purgeUserLabs(u.username)
      }
      await deleteUser(u.username)
      await reload()
    } catch (e) {
      setError(errorMessage(e, '失敗しました'))
    }
    setBusy(false)
  }

  return (
    <div className="admin-users">
      <h2>ユーザー管理</h2>
      <p className="admin-users__lead">
        利用者のアカウントを作る・パスワードを作り直す・削除する画面です（管理者だけが使えます）。作るのは、ログインだけに使う
        利用者のアカウントです。パスワードは作成時に1回だけ表示します。
      </p>
      {error && (
        <p className="admin-users__error" role="alert">
          {error}
        </p>
      )}

      {results && (
        <section className="admin-users__results" aria-label="作成の結果">
          <h3>結果（パスワードは今だけ表示されます）</h3>
          <p className="admin-users__warn">この画面を閉じると、パスワードは二度と見られません。本人に渡すために、先に保存してください。</p>
          <table>
            <thead>
              <tr>
                <th>ユーザー名</th>
                <th>パスワード</th>
                <th>結果</th>
              </tr>
            </thead>
            <tbody>
              {results.map((r) => (
                <tr key={r.username} className={r.password ? '' : 'admin-users__row-failed'}>
                  <td>{r.username}</td>
                  <td>
                    <code>{r.password}</code>
                  </td>
                  <td>{r.result}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="admin-users__actions">
            <button className="btn-primary" onClick={() => downloadCsv('fnl-accounts.csv', accountsToCsv(results))}>
              CSVで保存
            </button>
            <button onClick={() => setResults(null)}>閉じる</button>
          </div>
        </section>
      )}

      <section aria-label="1人を追加">
        <h3>1人を追加</h3>
        <form className="admin-users__form" onSubmit={onAdd}>
          <label>
            ユーザー名
            <input value={username} onChange={(e) => setUsername(e.target.value)} placeholder="student01" autoComplete="off" required />
          </label>
          <label>
            表示名（任意）
            <input value={fullName} onChange={(e) => setFullName(e.target.value)} placeholder="山田 太郎" autoComplete="off" />
          </label>
          <button className="btn-primary" type="submit" disabled={busy}>
            追加
          </button>
        </form>
      </section>

      <section aria-label="まとめて追加">
        <h3>まとめて追加（CSV）</h3>
        <p className="admin-users__hint">
          1列目がユーザー名、2列目が表示名、3列目が初期パスワード（どちらも省略可）。表計算ソフトからの貼り付けも使えます。<input type="file" accept=".csv,.txt,text/csv" onChange={(e) => void onCsvFile(e.target.files?.[0])} />
        </p>
        <textarea
          value={csvText}
          onChange={(e) => setCsvText(e.target.value)}
          rows={5}
          placeholder={'ユーザー名,表示名\nstudent01,山田 太郎\nstudent02,鈴木 花子'}
          aria-label="CSV"
        />
        {csvRows.length > 0 && (
          <p className={csvBad.length > 0 ? 'admin-users__error' : 'admin-users__hint'}>
            {csvOk.length} 人を登録できます
            {csvBad.length > 0 && `（${csvBad.length} 行に問題があります。直すまで登録できません）`}
          </p>
        )}
        {csvBad.length > 0 && (
          <ul className="admin-users__problems">
            {csvBad.map((r) => (
              <li key={r.line}>
                {r.line} 行目「{r.username}」：{r.error}
              </li>
            ))}
          </ul>
        )}
        <label className="admin-users__common">
          共通の初期パスワード（任意）
          <input type="text" value={commonPw} onChange={(e) => setCommonPw(e.target.value)} placeholder="空なら、1人ずつ自動で作ります" autoComplete="off" />
        </label>
        {commonPwProblem && <p className="admin-users__error">{commonPwProblem}</p>}
        {specifiedCount > 0 && !commonPwProblem && (
          <p className="admin-users__warn">
            {specifiedCount} 人は、指定したパスワードで作ります。同じパスワードを知る人どうしで、他人のアカウントに入れてしまうため、
            配ったらすぐに、全員が自分で変えるよう伝えてください（ナビの鍵のボタン）。
          </p>
        )}
        <button className="btn-primary" onClick={() => void onImport()} disabled={busy || csvBad.length > 0 || csvOk.length === 0 || !!commonPwProblem}>
          {csvOk.length > 0 ? `${csvOk.length} 人を登録` : '登録'}
        </button>
      </section>

      <section aria-label="ユーザーの一覧">
        <h3>ユーザーの一覧{users ? `（${users.length}人）` : ''}</h3>
        {users === null && !error && <p className="admin-users__hint">読み込み中…</p>}
        {users && (
          <div className="admin-users__actions">
            <button onClick={() => void onResetSelected()} disabled={busy || selected.size === 0}>
              選んだ {selected.size} 人のパスワードを再設定
            </button>
            <label className="admin-users__check">
              <input type="checkbox" checked={purgeLabs} onChange={(e) => setPurgeLabs(e.target.checked)} />
              削除するとき、その人のラボと保存データも消す
            </label>
          </div>
        )}
        {users && (
          <table>
            <thead>
              <tr>
                <th>
                  <input
                    type="checkbox"
                    aria-label="利用者をすべて選ぶ"
                    checked={users.some((u) => !u.isSuperuser) && users.filter((u) => !u.isSuperuser).every((u) => selected.has(u.username))}
                    onChange={(e) => setSelected(e.target.checked ? new Set(users.filter((u) => !u.isSuperuser).map((u) => u.username)) : new Set())}
                  />
                </th>
                <th>ユーザー名</th>
                <th>表示名</th>
                <th>区分</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {users.map((u) => {
                const locked = u.isSuperuser || u.username === me // 管理者と自分は、この画面から消せない
                return (
                  <tr key={u.username}>
                    <td>
                      {!u.isSuperuser && (
                        <input type="checkbox" aria-label={`${u.username} を選ぶ`} checked={selected.has(u.username)} onChange={() => toggle(u.username)} />
                      )}
                    </td>
                    <td>{u.username}</td>
                    <td>{u.displayName && u.displayName !== u.username ? u.displayName : ''}</td>
                    <td>{u.isSuperuser ? '管理者' : '利用者'}</td>
                    <td className="admin-users__row-actions">
                      <button onClick={() => void onReset(u)} disabled={busy}>
                        パスワード再設定
                      </button>
                      {u.isSuperuser ? (
                        <button
                          onClick={() => void onSetAdmin(u, false)}
                          disabled={busy || u.username === me || users.filter((x) => x.isSuperuser).length < 2}
                          title={u.username === me ? '自分自身は、はずせません（ほかの管理者にはずしてもらう）' : undefined}
                        >
                          管理者をやめる
                        </button>
                      ) : (
                        <button onClick={() => void onSetAdmin(u, true)} disabled={busy}>
                          管理者にする
                        </button>
                      )}
                      <button className="btn-danger" onClick={() => void onDelete(u)} disabled={busy || locked} title={locked ? '管理者と自分自身は、ここから削除できません（管理者は、先に「管理者をやめる」）' : undefined}>
                        削除
                      </button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </section>
    </div>
  )
}
