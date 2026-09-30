import DarkModeOutlinedIcon from '@mui/icons-material/DarkModeOutlined'
import LightModeOutlinedIcon from '@mui/icons-material/LightModeOutlined'
import { IconButton } from '@mui/material'
import type { PaletteMode } from '@mui/material/styles'

type ColorModeToggleProps = {
  mode: PaletteMode
  onToggle: () => void
}

export function ColorModeToggle({ mode, onToggle }: ColorModeToggleProps) {
  const nextMode = mode === 'light' ? 'dark' : 'light'

  return (
    <IconButton
      aria-label={`Switch to ${nextMode} mode`}
      title={`Switch to ${nextMode} mode`}
      onClick={onToggle}
      sx={{
        bgcolor: 'background.paper',
        border: '1px solid',
        borderColor: 'divider',
        color: 'text.primary',
      }}
    >
      {mode === 'light' ? <DarkModeOutlinedIcon /> : <LightModeOutlinedIcon />}
    </IconButton>
  )
}
