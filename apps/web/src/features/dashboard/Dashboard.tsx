import AccountTreeOutlinedIcon from '@mui/icons-material/AccountTreeOutlined'
import LogoutOutlinedIcon from '@mui/icons-material/LogoutOutlined'
import {
  AppBar,
  Avatar,
  Box,
  Button,
  Stack,
  Toolbar,
  Typography,
} from '@mui/material'
import type { PaletteMode } from '@mui/material/styles'
import { ColorModeToggle } from '../../components/ColorModeToggle'
import type { User } from '../../lib/api'

type DashboardProps = {
  user: User
  onLogout: () => Promise<void>
  colorMode: PaletteMode
  onToggleColorMode: () => void
}

export function Dashboard({ user, onLogout, colorMode, onToggleColorMode }: DashboardProps) {
  const fallbackInitial = user.display_name.trim().charAt(0).toUpperCase() || '?'

  return (
    <Box className="dashboard-shell">
      <AppBar
        color="transparent"
        elevation={0}
        position="static"
        sx={{ borderBottom: 1, borderColor: 'divider', backgroundColor: 'background.paper' }}
      >
        <Toolbar sx={{ minHeight: '76px !important', px: { xs: 2.25, md: '5vw' } }}>
          <Stack direction="row" spacing={1} sx={{ alignItems: 'center', color: 'primary.main' }}>
            <AccountTreeOutlinedIcon />
            <Typography sx={{ fontWeight: 700 }}>AI Workflow Studio</Typography>
          </Stack>
          <Box sx={{ flexGrow: 1 }} />
          <Stack direction="row" spacing={{ xs: 1, sm: 1.5 }} sx={{ alignItems: 'center' }}>
            <ColorModeToggle mode={colorMode} onToggle={onToggleColorMode} />
            <Avatar alt="" src={user.avatar_url ?? undefined} sx={{ bgcolor: 'primary.main', color: 'primary.contrastText' }}>
              {fallbackInitial}
            </Avatar>
            <Typography sx={{ display: { xs: 'none', sm: 'block' }, fontSize: '1rem', fontWeight: 600 }}>
              {user.display_name}
            </Typography>
            <Button
              onClick={() => void onLogout()}
              size="small"
              startIcon={<LogoutOutlinedIcon />}
              variant="outlined"
            >
              Sign out
            </Button>
          </Stack>
        </Toolbar>
      </AppBar>
      <Box className="dashboard-empty">
        <Typography className="eyebrow">Authenticated workspace</Typography>
        <Typography component="h1" variant="h2">Welcome, {user.display_name.split(' ')[0]}.</Typography>
        <Typography color="text.secondary" sx={{ mt: 1.5 }}>
          Your visual workflow dashboard will live here.
        </Typography>
      </Box>
    </Box>
  )
}
