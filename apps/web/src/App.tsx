import { useEffect, useState } from 'react'
import { AuthPage } from './features/auth/AuthPage'
import { Dashboard } from './features/dashboard/Dashboard'
import {
  beginOAuth,
  getProviders,
  getSession,
  logout,
  type ProviderAvailability,
  type ProviderName,
  type User,
} from './lib/api'
import './App.css'

function App() {
  const [user, setUser] = useState<User | null>(null)
  const [providers, setProviders] = useState<ProviderAvailability | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(() =>
    new URLSearchParams(window.location.search).get('auth_error'),
  )

  useEffect(() => {
    let active = true
    const authError = new URLSearchParams(window.location.search).get('auth_error')
    if (authError) {
      window.history.replaceState({}, '', window.location.pathname)
    }
    Promise.all([getSession(), getProviders()])
      .then(([currentUser, availableProviders]) => {
        if (!active) return
        setUser(currentUser)
        setProviders(availableProviders)
      })
      .catch(() => active && setError('The local API is unavailable. Check that it is running and try again.'))
      .finally(() => active && setLoading(false))
    return () => { active = false }
  }, [])

  async function handleLogout() {
    try {
      await logout()
      setUser(null)
    } catch {
      setError('We could not sign you out. Refresh the page and try again.')
    }
  }

  if (loading) return <div className="loading-screen"><span className="loader" /><p>Opening your workspace…</p></div>
  if (user) return <Dashboard user={user} onLogout={handleLogout} />
  return <AuthPage providers={providers} error={error} onContinue={(provider: ProviderName) => beginOAuth(provider)} />
}

export default App
