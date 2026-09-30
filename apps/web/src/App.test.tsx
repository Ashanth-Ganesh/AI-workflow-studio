import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import App from './App'
import { beginOAuth, getProviders, getSession, logout } from './lib/api'

vi.mock('./lib/api')

beforeEach(() => {
  vi.resetAllMocks()
  vi.mocked(getSession).mockResolvedValue(null)
  vi.mocked(getProviders).mockResolvedValue({
    github: false,
    google: true,
    microsoft: false,
  })
})

describe('App', () => {
  it('switches color mode and restores the saved choice', async () => {
    const user = userEvent.setup()
    render(<App />)

    await user.click(await screen.findByRole('button', { name: 'Switch to dark mode' }))

    expect(document.documentElement).toHaveAttribute('data-color-mode', 'dark')
    expect(window.localStorage.getItem('aiws-color-mode')).toBe('dark')
    expect(screen.getByRole('button', { name: 'Switch to light mode' })).toBeInTheDocument()

    cleanup()
    render(<App />)

    expect(await screen.findByRole('button', { name: 'Switch to light mode' })).toBeInTheDocument()
  })

  it('allows login only through configured providers', async () => {
    const user = userEvent.setup()
    render(<App />)

    expect(await screen.findByRole('button', { name: /continue with google/i })).toBeEnabled()
    expect(screen.getByRole('button', { name: /continue with github/i })).toBeDisabled()
    expect(screen.getByRole('button', { name: /continue with microsoft/i })).toBeDisabled()

    await user.click(screen.getByRole('button', { name: /continue with google/i }))
    expect(beginOAuth).toHaveBeenCalledWith('google')
  })

  it('allows a signed-in user to switch modes and sign out', async () => {
    const user = userEvent.setup()
    vi.mocked(getSession).mockResolvedValue({
      id: 'user-1',
      primary_email: 'alex@example.com',
      display_name: 'Alex Example',
      avatar_url: null,
    })
    vi.mocked(logout).mockResolvedValue()
    render(<App />)

    expect(await screen.findByText('Welcome, Alex.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Switch to dark mode' }))
    expect(document.documentElement).toHaveAttribute('data-color-mode', 'dark')

    await user.click(screen.getByRole('button', { name: 'Sign out' }))
    expect(await screen.findByRole('heading', { name: 'Sign in or create an account' })).toBeInTheDocument()
    expect(logout).toHaveBeenCalledOnce()
  })

  it('shows a connection error when the API cannot load', async () => {
    vi.mocked(getSession).mockRejectedValue(new Error('network unavailable'))
    render(<App />)

    expect(await screen.findByRole('alert')).toHaveTextContent('The local API is unavailable')
  })
})
