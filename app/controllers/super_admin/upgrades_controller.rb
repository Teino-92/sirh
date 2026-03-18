# frozen_string_literal: true
#
# SuperAdmin::UpgradesController — magic link upgrade OS → SIRH
#
# Flow :
#   1. Client soumet le formulaire de contact billing (request_upgrade)
#   2. AdminUpgradeMailer envoie l'email à l'équipe Izi-RH avec un magic link
#   3. Toi (Matteo) ouvres le lien → page de confirmation (GET /super_admin/upgrade/:token)
#   4. Tu cliques "Confirmer l'upgrade" → POST → upgrade_to_sirh! exécuté
#
# Sécurité :
#   - Token signé via Rails.application.message_verifier (HMAC-SHA256 + expiry 7 jours)
#   - Pas d'auth Devise nécessaire côté visiteur — le token est le secret
#   - Idempotent : si l'org est déjà SIRH, retourne un message sans erreur
#
# Pour activer le lien dans l'email : décommenter la ligne dans upgrade_requested.html.erb
# (marquée TODO MAGIC LINK)

module SuperAdmin
  class UpgradesController < ActionController::Base
    # Pas de layout admin — page minimaliste
    layout false

    VERIFIER_PURPOSE = "sirh_upgrade"
    TOKEN_EXPIRES_IN = 7.days

    # GET /super_admin/upgrade/:token
    # Affiche la page de confirmation avant d'exécuter l'upgrade
    def show
      @org = decode_token(params[:token])
      return render_invalid if @org.nil?

      @already_sirh = @org.sirh?
      @token        = params[:token]
    end

    # POST /super_admin/upgrade/:token
    # Exécute l'upgrade après confirmation
    def confirm
      org = decode_token(params[:token])
      return render_invalid if org.nil?

      if org.sirh?
        return render plain: "✅ #{org.name} est déjà sur le plan SIRH.", status: :ok
      end

      org.upgrade_to_sirh!

      Rails.logger.info "[MagicLink] upgrade_to_sirh! executed for org=#{org.id} (#{org.name})"

      render plain: <<~TEXT, status: :ok
        ✅ Upgrade effectué avec succès.

        Organisation : #{org.name} (ID #{org.id})
        Plan         : SIRH Essentiel
        Date         : #{Time.current.strftime('%d/%m/%Y %H:%M')}

        Les membres de l'équipe peuvent désormais accéder aux modules SIRH.
      TEXT
    end

    private

    def decode_token(token)
      payload = Rails.application.message_verifier(VERIFIER_PURPOSE).verify(token)
      Organization.find_by(id: payload[:org_id])
    rescue ActiveSupport::MessageVerifier::InvalidSignature,
           ActiveSupport::MessageExpired
      nil
    end

    def render_invalid
      render plain: "❌ Lien invalide ou expiré (validité : 7 jours).", status: :unprocessable_entity
    end
  end
end
