import type { User } from '../../lib/api'

type DashboardProps = { user: User; onLogout: () => Promise<void> }

export function Dashboard({ user, onLogout }: DashboardProps) {
  return (
    <main className="dashboard-shell">
      <header className="dashboard-header">
        <div className="dashboard-brand">AI Workflow Studio</div>
        <div className="user-menu">
          {user.avatar_url ? <img src={user.avatar_url} alt="" /> : <span>{user.display_name[0]}</span>}
          <div><strong>{user.display_name}</strong></div>
          <button type="button" onClick={() => void onLogout()}>Sign out</button>
        </div>
      </header>
      <section className="dashboard-empty">
        <p className="eyebrow">Authenticated workspace</p>
        <h1>Welcome, {user.display_name.split(' ')[0]}.</h1>
        <p>Your visual workflow dashboard will live here.</p>
      </section>
    </main>
  )
}
