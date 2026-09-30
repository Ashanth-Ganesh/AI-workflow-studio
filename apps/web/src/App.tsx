import { useEffect, useLayoutEffect, useMemo, useState } from 'react'
import { Box, CircularProgress, CssBaseline, Stack, Typography } from '@mui/material'
import { ThemeProvider, type PaletteMode } from '@mui/material/styles'
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
import { createAppTheme } from './theme'
import './App.css'

const colorModeStorageKey = 'aiws-color-mode'

function getInitialColorMode(): PaletteMode {
  try {
    return window.localStorage.getItem(colorModeStorageKey) === 'dark' ? 'dark' : 'light'
  } catch {
    return 'light'
  }
}

function App() {
  const [colorMode, setColorMode] = useState<PaletteMode>(getInitialColorMode)
  const theme = useMemo(() => createAppTheme(colorMode), [colorMode])
  const [user, setUser] = useState<User | null>(null)
  const [providers, setProviders] = useState<ProviderAvailability | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(() =>
    new URLSearchParams(window.location.search).get('auth_error'),
  )

  useLayoutEffect(() => {
    document.documentElement.dataset.colorMode = colorMode
    try {
      window.localStorage.setItem(colorModeStorageKey, colorMode)
    } catch {
      // The in-memory choice still works when browser storage is unavailable.
    }
  }, [colorMode])

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

  const toggleColorMode = () => setColorMode((current) => current === 'light' ? 'dark' : 'light')

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      {loading ? (
        <Box className="loading-screen">
          <Stack spacing={2} sx={{ alignItems: 'center' }}>
            <CircularProgress aria-label="Loading application" size={32} />
            <Typography color="text.secondary">Opening your workspace…</Typography>
          </Stack>
        </Box>
      ) : user ? (
        <Dashboard
          user={user}
          onLogout={handleLogout}
          colorMode={colorMode}
          onToggleColorMode={toggleColorMode}
        />
      ) : (
        <AuthPage
          providers={providers}
          error={error}
          onContinue={(provider: ProviderName) => beginOAuth(provider)}
          colorMode={colorMode}
          onToggleColorMode={toggleColorMode}
        />
      )}
    </ThemeProvider>
  )
}

export default App
