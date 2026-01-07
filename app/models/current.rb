# Thread-safe current context storage
# Utilisé pour stocker organization et employee dans le contexte de la requête
class Current < ActiveSupport::CurrentAttributes
  attribute :organization, :employee
end
