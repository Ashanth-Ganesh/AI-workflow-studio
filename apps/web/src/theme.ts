import { createTheme, type PaletteMode } from '@mui/material/styles'

export function createAppTheme(mode: PaletteMode) {
  return createTheme({
    palette: {
      mode,
      primary: mode === 'light'
        ? { main: '#28705d', dark: '#173c37', contrastText: '#ffffff' }
        : { main: '#89d9b4', dark: '#62b991', contrastText: '#10211c' },
      secondary: { main: mode === 'light' ? '#7d6bf2' : '#b4a6ff' },
      background: mode === 'light'
        ? { default: '#f7f8f5', paper: '#ffffff' }
        : { default: '#10191a', paper: '#1c2a2b' },
      text: mode === 'light'
        ? { primary: '#182225', secondary: '#687276' }
        : { primary: '#eef6f1', secondary: '#afc1b9' },
    },
    shape: { borderRadius: 10 },
    typography: {
      fontFamily: "'DM Sans', system-ui, sans-serif",
      h1: { fontFamily: "'Manrope', sans-serif", fontWeight: 600, letterSpacing: '-0.055em' },
      h2: { fontFamily: "'Manrope', sans-serif", fontWeight: 600, letterSpacing: '-0.04em' },
      button: { fontWeight: 600, textTransform: 'none' },
    },
    components: {
      MuiButton: {
        styleOverrides: {
          root: { minHeight: 52, borderRadius: 10 },
        },
      },
      MuiOutlinedInput: {
        styleOverrides: {
          root: { backgroundColor: mode === 'light' ? '#ffffff' : '#1c2a2b' },
        },
      },
    },
  })
}
