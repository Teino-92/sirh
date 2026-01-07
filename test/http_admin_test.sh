#!/bin/bash
# HTTP Tests for Admin Panel - Week 2
# Tests the application as if using a browser

set -e

BASE_URL="http://localhost:3000"
COOKIE_JAR="/tmp/easy-rh-test-cookies.txt"
rm -f "$COOKIE_JAR"

echo "================================================================================"
echo "HTTP TESTS - ADMIN PANEL WEEK 2"
echo "================================================================================"
echo ""

# Couleurs pour output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_test() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

fail_test() {
    echo -e "${RED}❌ FAIL:${NC} $1"
}

info_test() {
    echo -e "${YELLOW}ℹ️  INFO:${NC} $1"
}

# Helper: Extract CSRF token from HTML
get_csrf_token() {
    local html="$1"
    echo "$html" | grep -o 'name="authenticity_token"[^>]*value="[^"]*"' | sed 's/.*value="\([^"]*\)".*/\1/' | head -1
}

# Test 1: Page de login accessible
echo ""
echo "--- Test 1: Page de Login Accessible (Public) ---"
response=$(curl -s -w "\n%{http_code}" "$BASE_URL/employees/sign_in")
http_code=$(echo "$response" | tail -1)
if [ "$http_code" = "200" ]; then
    pass_test "Page de login accessible"
else
    fail_test "Page de login retourne $http_code"
fi

# Test 2: Admin panel sans auth devrait rediriger
echo ""
echo "--- Test 2: Admin Panel Sans Auth (Devrait Rediriger) ---"
http_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/admin/employees")
if [ "$http_code" = "302" ] || [ "$http_code" = "401" ]; then
    pass_test "Accès non authentifié redirigé ($http_code)"
else
    fail_test "Devrait rediriger (got $http_code)"
fi

# Test 3: Login TechCorp Admin
echo ""
echo "--- Test 3: Login avec admin@techcorp.fr ---"
# Get login page and CSRF token
login_page=$(curl -s -c "$COOKIE_JAR" "$BASE_URL/employees/sign_in")
csrf_token=$(get_csrf_token "$login_page")

if [ -z "$csrf_token" ]; then
    fail_test "Impossible d'extraire le CSRF token"
    exit 1
fi

info_test "CSRF token extrait"

# Post login form
login_response=$(curl -s -w "\n%{http_code}" \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -X POST "$BASE_URL/employees/sign_in" \
    -d "employee[email]=admin@techcorp.fr" \
    -d "employee[password]=password123" \
    -d "authenticity_token=$csrf_token" \
    -d "commit=Log+in")

login_code=$(echo "$login_response" | tail -1)
if [ "$login_code" = "302" ] || [ "$login_code" = "303" ]; then
    pass_test "Login réussi ($login_code redirect)"
else
    fail_test "Login échoué (got $login_code)"
    # Debug
    echo "$login_response" | head -20
fi

# Test 4: Accès admin panel après login
echo ""
echo "--- Test 4: Accès Admin Panel (Après Login) ---"
admin_response=$(curl -s -w "\n%{http_code}" -b "$COOKIE_JAR" -L "$BASE_URL/admin/employees")
admin_code=$(echo "$admin_response" | tail -1)
admin_body=$(echo "$admin_response" | sed '$d')

if [ "$admin_code" = "200" ]; then
    if echo "$admin_body" | grep -q "Employés\|Employees"; then
        pass_test "Admin panel accessible avec titre correct"
    else
        pass_test "Admin panel accessible (code 200)"
    fi
else
    fail_test "Admin panel inaccessible ($admin_code)"
fi

# Test 5: Multi-tenancy - vérifier emails affichés
echo ""
echo "--- Test 5: Multi-Tenancy - Liste Employés TechCorp ---"
if echo "$admin_body" | grep -q "techcorp.fr"; then
    has_techcorp=true
    pass_test "Emails TechCorp visibles"
else
    has_techcorp=false
    info_test "Pas d'emails TechCorp trouvés"
fi

if echo "$admin_body" | grep -q "innolabs.fr"; then
    fail_test "⚠️ SECURITY: Emails InnoLabs visibles pour admin TechCorp!"
else
    pass_test "Emails InnoLabs NON visibles (isolation OK)"
fi

# Test 6: Page organisation
echo ""
echo "--- Test 6: Page Organisation ---"
org_response=$(curl -s -w "\n%{http_code}" -b "$COOKIE_JAR" -L "$BASE_URL/admin/organization")
org_code=$(echo "$org_response" | tail -1)
if [ "$org_code" = "200" ]; then
    pass_test "Page organisation accessible"
else
    fail_test "Page organisation inaccessible ($org_code)"
fi

# Test 7: Logout
echo ""
echo "--- Test 7: Logout ---"
logout_code=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_JAR" -X DELETE "$BASE_URL/employees/sign_out")
rm -f "$COOKIE_JAR"
info_test "Déconnexion effectuée"

# Test 8: Login InnoLabs Admin
echo ""
echo "--- Test 8: Login avec admin@innolabs.fr ---"
login_page=$(curl -s -c "$COOKIE_JAR" "$BASE_URL/employees/sign_in")
csrf_token=$(get_csrf_token "$login_page")

login_response=$(curl -s -w "\n%{http_code}" \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -X POST "$BASE_URL/employees/sign_in" \
    -d "employee[email]=admin@innolabs.fr" \
    -d "employee[password]=password123" \
    -d "authenticity_token=$csrf_token" \
    -d "commit=Log+in")

login_code=$(echo "$login_response" | tail -1)
if [ "$login_code" = "302" ] || [ "$login_code" = "303" ]; then
    pass_test "Login InnoLabs réussi"
else
    fail_test "Login InnoLabs échoué ($login_code)"
fi

# Test 9: Vérifier isolation InnoLabs
echo ""
echo "--- Test 9: Multi-Tenancy - Liste Employés InnoLabs ---"
admin_response=$(curl -s -w "\n%{http_code}" -b "$COOKIE_JAR" -L "$BASE_URL/admin/employees")
admin_body=$(echo "$admin_response" | sed '$d')

if echo "$admin_body" | grep -q "innolabs.fr"; then
    pass_test "Emails InnoLabs visibles"
else
    info_test "Pas d'emails InnoLabs trouvés"
fi

if echo "$admin_body" | grep -q "techcorp.fr"; then
    fail_test "⚠️ SECURITY: Emails TechCorp visibles pour admin InnoLabs!"
else
    pass_test "Emails TechCorp NON visibles (isolation OK)"
fi

# Test 10: Cross-tenant access (CRITIQUE)
echo ""
echo "--- Test 10: Cross-Tenant Access Blocked (CRITICAL) ---"
# Essayer d'accéder à un employé TechCorp en étant connecté InnoLabs
# On va tester avec l'ID 13 (employé TechCorp si créé par le script de test)
cross_tenant_code=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_JAR" -L "$BASE_URL/admin/employees/13")

if [ "$cross_tenant_code" = "404" ] || [ "$cross_tenant_code" = "302" ]; then
    pass_test "Accès cross-tenant bloqué ($cross_tenant_code)"
elif [ "$cross_tenant_code" = "200" ]; then
    fail_test "🔴 CRITICAL: Accès cross-tenant AUTORISÉ - FAILLE SÉCURITÉ!"
else
    info_test "Cross-tenant response: $cross_tenant_code"
fi

# Cleanup
rm -f "$COOKIE_JAR"

echo ""
echo "================================================================================"
echo "TESTS TERMINÉS"
echo "================================================================================"
echo ""
echo "Pour des tests plus complets (UI, Turbo, modales), utilisez un vrai navigateur:"
echo "  1. Ouvrez http://localhost:3000"
echo "  2. Connectez-vous avec admin@techcorp.fr / password123"
echo "  3. Suivez la checklist dans docs/QA_WEEK2_ADMIN_PANEL.md"
echo ""
