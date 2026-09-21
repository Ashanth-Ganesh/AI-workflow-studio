import { createTheme } from '@mui/material/styles'

export const theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: '#28705d', dark: '#173c37', contrastText: '#ffffff' },
    secondary: { main: '#7d6bf2' },
    background: { default: '#f7f8f5', paper: '#ffffff' },
    text: { primary: '#182225', secondary: '#687276' },
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
        root: { backgroundColor: '#ffffff' },
      },
    },
  },
})
