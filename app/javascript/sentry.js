import * as Sentry from "@sentry/browser"

const dsn = document.head.querySelector("meta[name='sentry-dsn']")?.content
if (dsn) {
  Sentry.init({
    dsn,
    sendDefaultPii: true,
    integrations: [
      Sentry.feedbackIntegration({ colorScheme: "system" }),
    ],
  })
}
