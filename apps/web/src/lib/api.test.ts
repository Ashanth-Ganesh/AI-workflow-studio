import { afterEach, describe, expect, it, vi } from 'vitest'

import { getSession, logout } from './api'

afterEach(() => {
  vi.unstubAllGlobals()
  document.cookie = 'aiws_csrf=; Max-Age=0; path=/'
})

describe('API client', () => {
  it('treats an unauthorized session as signed out', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => 'Not authenticated',
    })
    vi.stubGlobal('fetch', fetchMock)

    await expect(getSession()).resolves.toBeNull()
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/auth/session',
      expect.objectContaining({ credentials: 'include' }),
    )
  })

  it('sends the CSRF cookie value when signing out', async () => {
    document.cookie = 'aiws_csrf=token%20value'
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 204 })
    vi.stubGlobal('fetch', fetchMock)

    await logout()

    expect(fetchMock).toHaveBeenCalledWith('/api/v1/auth/logout', {
      method: 'POST',
      credentials: 'include',
      headers: { Accept: 'application/json', 'X-CSRF-Token': 'token value' },
    })
  })
})
