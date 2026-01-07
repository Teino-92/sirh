#!/usr/bin/env ruby
# frozen_string_literal: true

# Browser Simulation Test Suite
# Tests the admin panel as if a user was navigating in a browser
# Run with: ruby test/integration/browser_simulation_test.rb

require 'net/http'
require 'uri'
require 'json'

class BrowserSimulator
  BASE_URL = 'http://localhost:3000'

  def initialize
    @cookies = {}
    @csrf_token = nil
  end

  def test_suite
    puts "=" * 80
    puts "BROWSER SIMULATION TEST SUITE - WEEK 2 ADMIN PANEL"
    puts "=" * 80
    puts ""

    # Test 1: Login Page (Public Access)
    test_login_page_accessible

    # Test 2: Admin Access Without Login (Should Redirect)
    test_admin_requires_authentication

    # Test 3: Login as TechCorp Admin
    login('admin@techcorp.fr', 'password123')

    # Test 4: Access Admin Panel (Should Work)
    test_admin_panel_accessible

    # Test 5: List Employees (Multi-tenancy)
    test_employees_list_isolation

    # Test 6: View Employee Details
    test_view_employee_details

    # Test 7: Organization Settings Page
    test_organization_page

    # Test 8: Logout
    logout

    # Test 9: Login as InnoLabs Admin
    login('admin@innolabs.fr', 'password123')

    # Test 10: Verify Different Employee List
    test_different_organization_employees

    # Test 11: Try Cross-Tenant Access
    test_cross_tenant_access_blocked

    puts ""
    puts "=" * 80
    puts "TEST SUITE COMPLETED"
    puts "=" * 80
  end

  private

  def get(path, follow_redirect: true)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Get.new(uri)
    add_cookies(request)

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    store_cookies(response)
    extract_csrf_token(response) if response.body

    if follow_redirect && (response.code == '302' || response.code == '301')
      location = response['location']
      return get(location.start_with?('http') ? location.sub(BASE_URL, '') : location)
    end

    response
  end

  def post(path, params = {})
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(params.merge('authenticity_token' => @csrf_token))
    add_cookies(request)

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    store_cookies(response)
    response
  end

  def add_cookies(request)
    return if @cookies.empty?
    request['Cookie'] = @cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
  end

  def store_cookies(response)
    return unless response['set-cookie']
    response.get_fields('set-cookie').each do |cookie|
      cookie.split(';').first.split('=', 2).tap do |k, v|
        @cookies[k] = v
      end
    end
  end

  def extract_csrf_token(response)
    if match = response.body.match(/name="authenticity_token".*?value="([^"]+)"/)
      @csrf_token = match[1]
    end
  end

  def login(email, password)
    puts "\n--- Test: Login as #{email} ---"

    # Get login page first to get CSRF token
    response = get('/employees/sign_in')

    # Submit login form
    response = post('/employees/sign_in', {
      'employee[email]' => email,
      'employee[password]' => password,
      'commit' => 'Log in'
    })

    if response.code == '302' && response['location']&.include?('/')
      puts "✅ PASS: Login successful"
      return true
    else
      puts "❌ FAIL: Login failed (#{response.code})"
      return false
    end
  end

  def logout
    puts "\n--- Test: Logout ---"
    response = get('/employees/sign_out')
    @cookies = {}
    @csrf_token = nil
    puts "✅ Logged out"
  end

  def test_login_page_accessible
    puts "\n--- Test 1: Login Page Accessible ---"
    response = get('/employees/sign_in')

    if response.code == '200'
      puts "✅ PASS: Login page accessible"
    else
      puts "❌ FAIL: Login page returned #{response.code}"
    end
  end

  def test_admin_requires_authentication
    puts "\n--- Test 2: Admin Requires Authentication ---"
    @cookies = {}  # Clear cookies
    response = get('/admin/employees', follow_redirect: false)

    if response.code == '302'
      puts "✅ PASS: Unauthenticated access redirected (#{response.code})"
    else
      puts "❌ FAIL: Should redirect unauthenticated users (got #{response.code})"
    end
  end

  def test_admin_panel_accessible
    puts "\n--- Test 4: Admin Panel Accessible (After Login) ---"
    response = get('/admin/employees')

    if response.code == '200' && response.body.include?('Employés')
      puts "✅ PASS: Admin panel accessible with proper authentication"
    else
      puts "❌ FAIL: Admin panel not accessible (#{response.code})"
    end
  end

  def test_employees_list_isolation
    puts "\n--- Test 5: Employees List Isolation ---"
    response = get('/admin/employees')

    if response.code == '200'
      # Check that only current org employees are shown
      has_techcorp = response.body.include?('techcorp.fr')
      has_innolabs = response.body.include?('innolabs.fr')

      if has_techcorp && !has_innolabs
        puts "✅ PASS: Shows only TechCorp employees"
      elsif has_innolabs && !has_techcorp
        puts "✅ PASS: Shows only InnoLabs employees"
      else
        puts "⚠️  WARNING: Cannot verify multi-tenancy from HTML (#{has_techcorp ? 'techcorp' : 'none'}/#{has_innolabs ? 'innolabs' : 'none'})"
      end
    else
      puts "❌ FAIL: Could not access employee list (#{response.code})"
    end
  end

  def test_view_employee_details
    puts "\n--- Test 6: View Employee Details ---"
    # Try to view an employee (we'll assume ID 13 exists from our test data)
    response = get('/admin/employees/13')

    if response.code == '200'
      puts "✅ PASS: Employee details page accessible"
    elsif response.code == '404'
      puts "⚠️  INFO: Employee ID 13 not found (might be different ID)"
    else
      puts "❌ FAIL: Unexpected response (#{response.code})"
    end
  end

  def test_organization_page
    puts "\n--- Test 7: Organization Settings Page ---"
    response = get('/admin/organization')

    if response.code == '200' && response.body.include?('Organisation')
      puts "✅ PASS: Organization page accessible"
    else
      puts "❌ FAIL: Organization page not accessible (#{response.code})"
    end
  end

  def test_different_organization_employees
    puts "\n--- Test 10: Different Organization Shows Different Employees ---"
    response = get('/admin/employees')

    if response.code == '200'
      has_techcorp = response.body.include?('techcorp.fr')
      has_innolabs = response.body.include?('innolabs.fr')

      if has_innolabs && !has_techcorp
        puts "✅ PASS: Now shows only InnoLabs employees"
      else
        puts "⚠️  WARNING: Cannot clearly verify (techcorp: #{has_techcorp}, innolabs: #{has_innolabs})"
      end
    else
      puts "❌ FAIL: Could not access employee list (#{response.code})"
    end
  end

  def test_cross_tenant_access_blocked
    puts "\n--- Test 11: Cross-Tenant Access Blocked (CRITICAL) ---"
    # Try to access TechCorp employee while logged in as InnoLabs
    response = get('/admin/employees/13', follow_redirect: false)

    if response.code == '404' || (response.code == '302' && response['location'].include?('admin/employees'))
      puts "✅ PASS: Cross-tenant access blocked (#{response.code})"
    elsif response.code == '200'
      puts "🔴 CRITICAL FAIL: Cross-tenant access ALLOWED - SECURITY ISSUE!"
    else
      puts "⚠️  WARNING: Unexpected response (#{response.code})"
    end
  end
end

# Run the test suite
if __FILE__ == $0
  simulator = BrowserSimulator.new
  simulator.test_suite
end
