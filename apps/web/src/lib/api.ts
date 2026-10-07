export type User = {
  id: string
  primary_email: string
  display_name: string
  avatar_url: string | null
}

export type ProviderName = 'github' | 'google' | 'microsoft'
export type ProviderAvailability = Record<ProviderName, boolean>

const csrfCookieName = import.meta.env.VITE_CSRF_COOKIE_NAME ?? 'aiws_csrf'

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    credentials: 'include',
    headers: { Accept: 'application/json', ...init?.headers },
  })
  if (!response.ok) {
    throw new ApiError(response.status, await response.text())
  }
  if (response.status === 204) return undefined as T
  return response.json() as Promise<T>
}

export class ApiError extends Error {
  readonly status: number

  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

export async function getSession(): Promise<User | null> {
  try {
    const response = await request<{ user: User }>('/api/v1/auth/session')
    return response.user
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) return null
    throw error
  }
}

export async function getProviders(): Promise<ProviderAvailability> {
  const response = await request<{ providers: ProviderAvailability }>(
    '/api/v1/auth/providers',
  )
  return response.providers
}

export function beginOAuth(provider: ProviderName): void {
  window.location.assign(`/api/v1/auth/oauth/${provider}/start?return_to=/`)
}

export async function logout(): Promise<void> {
  const csrfToken = readCookie(csrfCookieName)
  if (!csrfToken) throw new Error('Your security token is missing. Refresh and try again.')
  await request<void>('/api/v1/auth/logout', {
    method: 'POST',
    headers: { 'X-CSRF-Token': csrfToken },
  })
}

function readCookie(name: string): string | null {
  const prefix = `${encodeURIComponent(name)}=`
  const part = document.cookie.split('; ').find((cookie) => cookie.startsWith(prefix))
  return part ? decodeURIComponent(part.slice(prefix.length)) : null
}
