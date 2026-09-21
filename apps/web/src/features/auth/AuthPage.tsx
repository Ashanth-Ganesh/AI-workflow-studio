import AccountTreeOutlinedIcon from '@mui/icons-material/AccountTreeOutlined'
import ArrowForwardIcon from '@mui/icons-material/ArrowForward'
import GitHubIcon from '@mui/icons-material/GitHub'
import GoogleIcon from '@mui/icons-material/Google'
import LockOutlinedIcon from '@mui/icons-material/LockOutlined'
import MicrosoftIcon from '@mui/icons-material/Microsoft'
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Stack,
  Typography,
} from '@mui/material'
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
    <Box component="main" className="auth-layout">
      <Box component="section" className="auth-story" aria-labelledby="product-name">
        <Stack className="brand-lockup" direction="row">
          <BrandMark />
          <Typography component="span" id="product-name">AI Workflow Studio</Typography>
        </Stack>

        <Box className="story-copy">
          <Typography className="eyebrow">Build beyond boundaries</Typography>
          <Typography component="h1" variant="h1">
            Design intelligent workflows at the speed of thought.
          </Typography>
          <Typography className="story-intro">
            Connect models, data, and services across any cloud in one visual workspace.
          </Typography>
        </Box>

        <Box className="workflow-preview" aria-hidden="true">
          <Box className="preview-node input-node">
            <span className="node-dot coral" />
            <div><small>INPUT</small><strong>Customer brief</strong></div>
          </Box>
          <Box className="connector connector-one" />
          <Box className="preview-node model-node">
            <span className="node-dot violet" />
            <div><small>INTELLIGENCE</small><strong>Generate insight</strong></div>
          </Box>
          <Box className="connector connector-two" />
          <Box className="preview-node output-node">
            <span className="node-dot mint" />
            <div><small>OUTPUT</small><strong>Structured result</strong></div>
          </Box>
        </Box>

        <Typography className="story-footnote">
          Cloud agnostic by design · Your credentials stay private
        </Typography>
      </Box>

      <Box component="section" className="auth-panel" aria-labelledby="auth-title">
        <Card className="auth-card" elevation={0} sx={{ backgroundColor: 'transparent' }}>
          <CardContent sx={{ p: 0, '&:last-child': { pb: 0 } }}>
            <Stack className="mobile-brand" direction="row">
              <BrandMark />
              <Typography component="span">AI Workflow Studio</Typography>
            </Stack>
            <Typography className="eyebrow">Your workspace awaits</Typography>
            <Typography component="h2" id="auth-title" variant="h2">
              Sign in or create an account
            </Typography>
            <Typography className="auth-subtitle">
              One secure step is all it takes. New identities automatically create a workspace account.
            </Typography>

            {error && <Alert severity="error" sx={{ mb: 2.5 }}>{error}</Alert>}

            <Stack aria-label="Identity providers" className="provider-list" spacing={1.5}>
              {providers.map((provider) => {
                const configured = availability?.[provider] ?? false
                return (
                  <Button
                    disabled={!configured}
                    endIcon={<ArrowForwardIcon />}
                    fullWidth
                    key={provider}
                    onClick={() => onContinue(provider)}
                    startIcon={<ProviderIcon provider={provider} />}
                    title={configured ? undefined : `${providerLabels[provider]} is not configured locally`}
                    variant="outlined"
                    sx={{
                      justifyContent: 'space-between',
                      borderColor: 'rgba(24, 34, 37, 0.16)',
                      color: 'text.primary',
                      '&:hover': { borderColor: 'primary.main', backgroundColor: 'rgba(40, 112, 93, 0.04)' },
                    }}
                  >
                    {providerLabels[provider]}
                  </Button>
                )
              })}
            </Stack>

            {configuredCount === 0 && (
              <Alert severity="warning" sx={{ mt: 2.5 }}>
                Add OAuth client credentials to <code>.env</code> to enable a provider.
              </Alert>
            )}

            <Typography className="legal-copy">
              By continuing, you agree to the Terms of Service and acknowledge the Privacy Policy.
            </Typography>
          </CardContent>
        </Card>
        <Stack className="security-note" direction="row">
          <LockOutlinedIcon fontSize="small" />
          <Typography variant="caption">Secured with server-side sessions</Typography>
        </Stack>
      </Box>
    </Box>
  )
}

function BrandMark() {
  return <AccountTreeOutlinedIcon className="brand-mark" aria-label="AI Workflow Studio" />
}

function ProviderIcon({ provider }: { provider: ProviderName }) {
  const iconSx = { fontSize: 22 }
  if (provider === 'google') return <GoogleIcon sx={{ ...iconSx, color: '#4285f4' }} />
  if (provider === 'microsoft') return <MicrosoftIcon sx={iconSx} />
  return <GitHubIcon sx={iconSx} />
}
