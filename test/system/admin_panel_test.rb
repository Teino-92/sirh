# frozen_string_literal: true

require "application_system_test_case"

class AdminPanelTest < ApplicationSystemTestCase
  setup do
    # Créer 2 organisations
    @techcorp = Organization.create!(
      name: 'TechCorp',
      settings: { work_week_hours: 35, rtt_enabled: true }
    )

    @innolabs = Organization.create!(
      name: 'InnoLabs',
      settings: { work_week_hours: 39, rtt_enabled: false }
    )

    # Créer des admins
    @admin_techcorp = Employee.create!(
      organization: @techcorp,
      email: 'admin.test@techcorp.fr',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Admin',
      last_name: 'TechCorp',
      role: 'admin',
      contract_type: 'CDI',
      start_date: Date.current
    )

    @admin_innolabs = Employee.create!(
      organization: @innolabs,
      email: 'admin.test@innolabs.fr',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Admin',
      last_name: 'InnoLabs',
      role: 'admin',
      contract_type: 'CDI',
      start_date: Date.current
    )

    # Créer des employés pour TechCorp
    @employee_techcorp = Employee.create!(
      organization: @techcorp,
      email: 'emp1@techcorp.fr',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Jean',
      last_name: 'Dupont',
      role: 'employee',
      contract_type: 'CDI',
      start_date: Date.current
    )

    # Créer des employés pour InnoLabs
    @employee_innolabs = Employee.create!(
      organization: @innolabs,
      email: 'emp1@innolabs.fr',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Sophie',
      last_name: 'Bernard',
      role: 'employee',
      contract_type: 'CDD',
      start_date: Date.current
    )
  end

  test "admin can access admin panel" do
    # Login
    visit employees_sign_in_path
    fill_in 'Email', with: @admin_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Accéder au panel admin
    visit admin_employees_path

    # Vérifier qu'on est sur la bonne page
    assert_selector 'h1', text: 'Employés'
    assert_current_path admin_employees_path
  end

  test "employee cannot access admin panel" do
    # Login en tant qu'employé
    visit employees_sign_in_path
    fill_in 'Email', with: @employee_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Tenter d'accéder au panel admin
    visit admin_employees_path

    # Devrait être redirigé avec message d'erreur
    assert_no_selector 'h1', text: 'Employés'
    # Vérifier message d'erreur (flash)
    assert_text 'autorisé', wait: 5
  end

  test "multi-tenancy: admin sees only their organization employees" do
    # Login TechCorp admin
    visit employees_sign_in_path
    fill_in 'Email', with: @admin_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Aller sur la liste des employés
    visit admin_employees_path

    # Doit voir les employés TechCorp
    assert_text @employee_techcorp.email
    assert_text @admin_techcorp.email

    # NE DOIT PAS voir les employés InnoLabs
    assert_no_text @employee_innolabs.email
    assert_no_text @admin_innolabs.email
  end

  test "multi-tenancy: cannot access employee from another org" do
    # Login TechCorp admin
    visit employees_sign_in_path
    fill_in 'Email', with: @admin_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Tenter d'accéder directement à un employé InnoLabs
    visit admin_employee_path(@employee_innolabs)

    # Devrait avoir une erreur 404 ou redirection
    assert_no_text @employee_innolabs.first_name
    # La page devrait montrer une erreur ou rediriger
    assert_current_path admin_employees_path
  end

  test "create new employee" do
    # Login
    visit employees_sign_in_path
    fill_in 'Email', with: @admin_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Aller sur admin
    visit admin_employees_path

    # Cliquer sur "Nouvel Employé"
    click_link 'Nouvel Employé'

    # Remplir le formulaire (dans la modale Turbo)
    within '#modal' do
      fill_in 'Prénom', with: 'Nouveau'
      fill_in 'Nom', with: 'Employé'
      fill_in 'Email', with: 'nouveau@techcorp.fr'
      fill_in 'Mot de passe', with: 'password123'
      fill_in 'Confirmation du mot de passe', with: 'password123'
      select 'CDI', from: 'Type de contrat'
      fill_in 'Date d\'entrée', with: Date.current.to_s

      click_button 'Créer l\'employé'
    end

    # Vérifier le message de succès
    assert_text 'Employé créé avec succès'

    # Vérifier que l'employé est dans la liste
    visit admin_employees_path
    assert_text 'nouveau@techcorp.fr'
  end

  test "view employee details" do
    # Login
    visit employees_sign_in_path
    fill_in 'Email', with: @admin_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Aller voir les détails d'un employé
    visit admin_employee_path(@employee_techcorp)

    # Vérifier les informations
    assert_text @employee_techcorp.first_name
    assert_text @employee_techcorp.last_name
    assert_text @employee_techcorp.email
    assert_text 'CDI'
  end

  test "access organization settings" do
    # Login
    visit employees_sign_in_path
    fill_in 'Email', with: @admin_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Accéder aux paramètres organisation
    visit admin_organization_path

    # Vérifier les infos affichées
    assert_text 'TechCorp'
    assert_text '35' # heures de travail
  end

  test "update organization settings" do
    # Login
    visit employees_sign_in_path
    fill_in 'Email', with: @admin_techcorp.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'

    # Accéder à l'édition organisation
    visit edit_admin_organization_path

    # Modifier les paramètres
    fill_in 'Nom', with: 'TechCorp Updated'
    fill_in 'Heures hebdomadaires', with: '37'

    click_button 'Enregistrer'

    # Vérifier le message de succès
    assert_text 'Paramètres mis à jour avec succès'

    # Vérifier les modifications
    @techcorp.reload
    assert_equal 'TechCorp Updated', @techcorp.name
    assert_equal 37, @techcorp.settings['work_week_hours']
  end
end
