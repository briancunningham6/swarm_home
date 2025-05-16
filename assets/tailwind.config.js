// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin');

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/swarm_ex_web.ex',
    '../lib/swarm_ex_web/**/*.*ex'
  ],
  theme: {
    extend: {
      colors: {}
    }
  },
  plugins: []
};