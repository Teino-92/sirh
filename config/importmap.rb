# Pin npm packages by running ./bin/importmap

pin "application"
pin "sentry"
pin "@sentry/browser", to: "https://esm.sh/@sentry/browser@8"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "canvas-confetti", to: "https://ga.jspm.io/npm:canvas-confetti@1.9.3/dist/confetti.module.mjs"
pin_all_from "app/javascript/controllers", under: "controllers"
# GridStack is loaded via <script> tag on the dashboard page (UMD bundle, no ESM build available)
