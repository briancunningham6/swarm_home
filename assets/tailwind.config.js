// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin')
const fs = require('fs')
const path = require('path')

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/swarm_ex_web.ex',
    '../lib/swarm_ex_web/**/*.*ex'
  ],
  theme: {
    extend: {
      colors: {}
    },
  },
  plugins: []
}/* /Users/user/dev/swarm_home/assets/css/app.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Add any of your custom CSS below */
body {
    /* example custom style */
    /* background-color: #f8f9fa; */
}
