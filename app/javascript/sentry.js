import * as Sentry from "@sentry/browser"

const dsn = document.head.querySelector("meta[name='sentry-dsn']")?.content
if (dsn) {
  Sentry.init({
    dsn,
    sendDefaultPii: true,
    integrations: [
      Sentry.feedbackIntegration({
        colorScheme: "system",
        showBranding: false,
        buttonLabel: "Signaler un bug",
        submitButtonLabel: "Envoyer",
        cancelButtonLabel: "Annuler",
        formTitle: "Signaler un problème",
        nameLabel: "Nom",
        namePlaceholder: "Votre nom",
        emailLabel: "Email",
        emailPlaceholder: "votre@email.com",
        messageLabel: "Description",
        messagePlaceholder: "Décrivez le problème rencontré…",
        successMessageText: "Merci pour votre retour !",
        isRequiredLabel: "(obligatoire)",
        addScreenshotButtonLabel: "Ajouter une capture d'écran",
        removeScreenshotButtonLabel: "Supprimer la capture",
      }),
    ],
  })
}
