import type { ProviderAvailability, ProviderName } from '../../lib/api'

type AuthPageProps = {
  providers: ProviderAvailability | null
  error: string | null
  onContinue: (provider: ProviderName) => void
}

const providerLabels: Record<ProviderName, string> = {
  google: 'Continue with Google',
  github: 'Continue with GitHub',
  microsoft: 'Continue with Microsoft',
}

const providers: ProviderName[] = ['google', 'github', 'microsoft']

export function AuthPage({ providers: availability, error, onContinue }: AuthPageProps) {
  const configuredCount = availability
    ? Object.values(availability).filter(Boolean).length
    : null

  return (
    <main className="auth-layout">
      <section className="auth-story" aria-labelledby="product-name">
        <div className="brand-lockup">
          <BrandMark />
          <span id="product-name">AI Workflow Studio</span>
        </div>

        <div className="story-copy">
          <p className="eyebrow">Build beyond boundaries</p>
          <h1>Design intelligent workflows at the speed of thought.</h1>
          <p className="story-intro">
            Connect models, data, and services across any cloud in one visual workspace.
          </p>
        </div>

        <div className="workflow-preview" aria-hidden="true">
          <div className="preview-node input-node">
            <span className="node-dot coral" />
            <div><small>INPUT</small><strong>Customer brief</strong></div>
          </div>
          <div className="connector connector-one" />
          <div className="preview-node model-node">
            <span className="node-dot violet" />
            <div><small>INTELLIGENCE</small><strong>Generate insight</strong></div>
          </div>
          <div className="connector connector-two" />
          <div className="preview-node output-node">
            <span className="node-dot mint" />
            <div><small>OUTPUT</small><strong>Structured result</strong></div>
          </div>
        </div>

        <p className="story-footnote">Cloud agnostic by design · Your credentials stay private</p>
      </section>

      <section className="auth-panel" aria-labelledby="auth-title">
        <div className="auth-card">
          <div className="mobile-brand"><BrandMark /><span>AI Workflow Studio</span></div>
          <p className="eyebrow">Your workspace awaits</p>
          <h2 id="auth-title">Sign in or create an account</h2>
          <p className="auth-subtitle">
            One secure step is all it takes. New identities automatically create a workspace account.
          </p>

          {error && <div className="alert" role="alert">{error}</div>}

          <div className="provider-list" aria-label="Identity providers">
            {providers.map((provider) => {
              const configured = availability?.[provider] ?? false
              return (
                <button
                  className="provider-button"
                  disabled={!configured}
                  key={provider}
                  onClick={() => onContinue(provider)}
                  type="button"
                  title={configured ? undefined : `${providerLabels[provider]} is not configured locally`}
                >
                  <ProviderIcon provider={provider} />
                  <span>{providerLabels[provider]}</span>
                  <span className="arrow" aria-hidden="true">→</span>
                </button>
              )
            })}
          </div>

          {configuredCount === 0 && (
            <p className="configuration-note">
              Add OAuth client credentials to <code>.env</code> to enable a provider.
            </p>
          )}

          <p className="legal-copy">
            By continuing, you agree to the Terms of Service and acknowledge the Privacy Policy.
          </p>
        </div>
        <p className="security-note"><LockIcon /> Secured with server-side sessions</p>
      </section>
    </main>
  )
}

function BrandMark() {
  return (
    <svg className="brand-mark" viewBox="0 0 44 44" role="img" aria-label="AI Workflow Studio">
      <path d="M11 10.5h9.5v9.5H11zM23.5 24H33v9.5h-9.5z" />
      <path d="M20.5 15.25h5A7.5 7.5 0 0 1 33 22.75V24M23.5 28.75h-5A7.5 7.5 0 0 1 11 21.25V20" fill="none" stroke="currentColor" strokeWidth="2.5" />
    </svg>
  )
}

function ProviderIcon({ provider }: { provider: ProviderName }) {
  if (provider === 'google') {
    return <span className="provider-icon google-icon" aria-hidden="true">G</span>
  }
  if (provider === 'microsoft') {
    return <span className="provider-icon microsoft-icon" aria-hidden="true"><i /><i /><i /><i /></span>
  }
  return (
    <svg className="provider-icon" viewBox="0 0 24 24" aria-hidden="true">
      <path fill="currentColor" d="M12 .7A11.5 11.5 0 0 0 8.36 23.1c.58.1.79-.25.79-.56v-2.23c-3.22.7-3.9-1.37-3.9-1.37-.53-1.34-1.29-1.7-1.29-1.7-1.05-.72.08-.71.08-.71 1.16.08 1.78 1.2 1.78 1.2 1.04 1.77 2.72 1.26 3.38.96.1-.75.4-1.26.74-1.55-2.57-.3-5.27-1.28-5.27-5.68 0-1.26.45-2.29 1.19-3.1-.12-.29-.52-1.47.11-3.06 0 0 .97-.31 3.16 1.18A10.97 10.97 0 0 1 12 6.1c.98 0 1.95.13 2.87.38 2.2-1.49 3.16-1.18 3.16-1.18.63 1.59.23 2.77.11 3.07.74.8 1.19 1.83 1.19 3.09 0 4.42-2.71 5.38-5.29 5.67.42.36.79 1.07.79 2.16v3.25c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .7Z" />
    </svg>
  )
}

function LockIcon() {
  return <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M6.5 8V6a3.5 3.5 0 0 1 7 0v2M5 8h10v8H5z" fill="none" stroke="currentColor" strokeWidth="1.5" /></svg>
}
