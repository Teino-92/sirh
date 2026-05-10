require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /" do
    it "renders home with Manager OS landing content" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Le manager OS")
      expect(response.body).to include("19 €")
      expect(response.body).to include("Manager OS")
    end

    it "does not render the SIRH header link" do
      get "/"
      expect(response.body).not_to match(%r{<a[^>]*href="/sirh"[^>]*>\s*SIRH\s*</a>})
    end
  end

  describe "GET /manager-os" do
    it "redirects 301 to /" do
      get "/manager-os"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/")
    end
  end

  describe "GET /sirh" do
    it "returns OK" do
      get "/sirh"
      expect(response).to have_http_status(:ok)
    end

    it "includes noindex meta tag" do
      get "/sirh"
      expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
    end
  end
end
