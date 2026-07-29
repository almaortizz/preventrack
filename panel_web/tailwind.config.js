/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#004B87',
          50: '#e6eef5',
          100: '#cddde9',
          200: '#9bbbd4',
          300: '#6999be',
          400: '#3777a9',
          500: '#004B87',
          600: '#003c6c',
          700: '#002d51',
          800: '#001e36',
          900: '#000f1b',
        },
        secondary: {
          DEFAULT: '#00AEEF',
          50: '#e6f8fe',
          100: '#ccf1fd',
          200: '#99e2fb',
          300: '#66d4f9',
          400: '#33c5f7',
          500: '#00AEEF',
          600: '#008bbf',
          700: '#00688f',
          800: '#004660',
          900: '#002330',
        },
        tertiary: '#F5F7FA',
        neutral: {
          DEFAULT: '#1A1C1E',
          50: '#f2f2f2',
          100: '#d9d9da',
          200: '#b3b3b5',
          300: '#8c8c90',
          400: '#66666b',
          500: '#404046',
          600: '#333337',
          700: '#262629',
          800: '#1A1C1E',
          900: '#0d0e0f',
        },
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
