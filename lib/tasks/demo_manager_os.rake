# frozen_string_literal: true
# =============================================================================
# rake demo:manager_os
# Crée une organisation Manager OS démo bien seedée pour screenshots
# =============================================================================

namespace :demo do
  desc "Crée une org Manager OS démo (manager + 5 collaborateurs) pour screenshots"
  task manager_os: :environment do
    ActsAsTenant.without_tenant do

      puts "🧹 Nettoyage org Manager OS existante..."
      existing = Organization.find_by(name: "Studio Créatif Demo")
      if existing
        ActsAsTenant.with_tenant(existing) do
          [
            OnboardingTask, OnboardingReview, EmployeeOnboarding,
            OnboardingTemplateTask, OnboardingTemplate,
            TrainingAssignment, Training,
            ActionItem, OneOnOne, Objective,
            TimeEntry, LeaveRequest, LeaveBalance,
            WorkSchedule, Notification
          ].each(&:destroy_all)
        end
        Employee.where(organization: existing).destroy_all
        existing.destroy
      end

      puts "🏢 Création organisation Manager OS..."
      org = Organization.create!(
        name:          "Studio Créatif Demo",
        plan:          "manager_os",
        billing_model: "per_team",
        trial_ends_at: 30.days.from_now,
        settings: {
          "work_week_hours"     => 35,
          "rtt_enabled"        => false,
          "cp_acquisition_rate" => 2.5
        }
      )

      Subscription.create!(
        organization:           org,
        plan:                   "manager_os",
        status:                 "active",
        stripe_customer_id:     "cus_demo_manager_os",
        stripe_subscription_id: "sub_demo_manager_os",
        commitment_end_at:      12.months.from_now
      )

      puts "👤 Création du manager (admin)..."
      manager = ActsAsTenant.with_tenant(org) do
        Employee.create!(
          organization:  org,
          first_name:    "Lucas",
          last_name:     "Martin",
          email:         "lucas.martin@studio-demo.fr",
          password:      "password123",
          role:          "admin",
          job_title:     "Directeur Créatif",
          department:    "Direction",
          contract_type: "CDI",
          start_date:    2.years.ago.to_date,
          settings:      { "active" => true }
        )
      end

      LeaveBalance.create!([
        { organization: org, employee: manager, leave_type: "CP",  balance: 18.0, used_this_year: 7.0 },
        { organization: org, employee: manager, leave_type: "RTT", balance: 0.0,  used_this_year: 0.0 }
      ])

      puts "👥 Création des collaborateurs..."
      team_attrs = [
        { first_name: "Sophie",  last_name: "Dubois",  job_title: "Designer UI/UX",    department: "Design",     start_date: 18.months.ago.to_date, cp: 12.0, cp_used: 3.0  },
        { first_name: "Thomas",  last_name: "Bernard", job_title: "Développeur Front",  department: "Tech",       start_date: 14.months.ago.to_date, cp: 10.0, cp_used: 5.0  },
        { first_name: "Camille", last_name: "Petit",   job_title: "Chef de Projet",     department: "Production", start_date: 8.months.ago.to_date,  cp: 6.0,  cp_used: 0.0  },
        { first_name: "Antoine", last_name: "Leroy",   job_title: "Motion Designer",    department: "Design",     start_date: 22.months.ago.to_date, cp: 20.0, cp_used: 10.0 },
        { first_name: "Manon",   last_name: "Garcia",  job_title: "Chargée de Comm.",   department: "Marketing",  start_date: 6.months.ago.to_date,  cp: 4.0,  cp_used: 0.0  }
      ]

      employees = {}
      team_attrs.each do |attrs|
        emp = ActsAsTenant.with_tenant(org) do
          Employee.create!(
            organization:  org,
            first_name:    attrs[:first_name],
            last_name:     attrs[:last_name],
            email:         "#{attrs[:first_name].downcase}.#{attrs[:last_name].downcase}@studio-demo.fr",
            password:      "password123",
            role:          "employee",
            job_title:     attrs[:job_title],
            department:    attrs[:department],
            contract_type: "CDI",
            start_date:    attrs[:start_date],
            manager_id:    manager.id,
            settings:      { "active" => true }
          )
        end
        LeaveBalance.create!(organization: org, employee: emp, leave_type: "CP",
                             balance: attrs[:cp], used_this_year: attrs[:cp_used])
        employees[attrs[:first_name]] = emp
      end

      sophie  = employees["Sophie"]
      thomas  = employees["Thomas"]
      camille = employees["Camille"]
      antoine = employees["Antoine"]
      manon   = employees["Manon"]

      # -----------------------------------------------------------------------
      puts "📅 Demandes de congés..."
      ActsAsTenant.with_tenant(org) do
        LeaveRequest.create!(organization: org, employee: sophie, leave_type: "CP",
          start_date: 2.weeks.from_now.to_date, end_date: 2.weeks.from_now.to_date + 4.days,
          days_count: 5, status: "pending", reason: "Vacances d'été anticipées")

        LeaveRequest.create!(organization: org, employee: thomas, leave_type: "CP",
          start_date: 1.week.ago.to_date, end_date: 1.week.ago.to_date + 2.days,
          days_count: 3, status: "approved", approved_by: manager, approved_at: 5.days.ago)
      end

      # -----------------------------------------------------------------------
      puts "🕐 Entrées de temps..."
      ActsAsTenant.with_tenant(org) do
        [manager, sophie].each do |emp|
          3.times do |i|
            day = (i + 1).days.ago.to_date
            next if day.saturday? || day.sunday?
            TimeEntry.create!(organization: org, employee: emp,
              clock_in: day.to_time + 9.hours, clock_out: day.to_time + 18.hours,
              duration_minutes: 480)
          end
        end
      end

      # -----------------------------------------------------------------------
      puts "📚 Formations..."
      ActsAsTenant.with_tenant(org) do
        training_figma = Training.create!(
          organization: org, title: "Figma avancé — composants & auto-layout",
          description: "Maîtriser les composants Figma pour accélérer les maquettes",
          training_type: "e_learning", duration_estimate: 120, provider: "Figma Academy"
        )
        training_notion = Training.create!(
          organization: org, title: "Notion pour les équipes créatives",
          description: "Mettre en place un wiki d'équipe et des tableaux de projet",
          training_type: "e_learning", duration_estimate: 90, provider: "Notion HQ"
        )
        training_motion = Training.create!(
          organization: org, title: "After Effects — motion design fondamentaux",
          description: "Animations, keyframes et exports optimisés",
          training_type: "e_learning", duration_estimate: 180, provider: "Adobe Learning"
        )

        # Assignments
        TrainingAssignment.create!(training: training_figma,   employee: sophie,
          assigned_by_id: manager.id, status: "in_progress", assigned_at: 1.week.ago,
          deadline: 3.weeks.from_now.to_date)
        TrainingAssignment.create!(training: training_notion,  employee: camille,
          assigned_by_id: manager.id, status: "assigned", assigned_at: 3.days.ago,
          deadline: 2.weeks.from_now.to_date)
        TrainingAssignment.create!(training: training_motion,  employee: antoine,
          assigned_by_id: manager.id, status: "completed", assigned_at: 6.weeks.ago,
          deadline: 3.weeks.ago.to_date, completed_at: 3.weeks.ago)
      end

      # -----------------------------------------------------------------------
      puts "📋 Templates d'onboarding..."
      ActsAsTenant.with_tenant(org) do
        tpl_design = OnboardingTemplate.create!(
          organization: org, name: "Intégration Designer", duration_days: 90, active: true,
          description: "Parcours d'intégration pour les profils créatifs (UI/UX, motion)"
        )
        [
          { title: "Remise du matériel + accès outils",     task_type: "manual",        assigned_to_role: "manager",  due_day_offset: 0,  position: 1 },
          { title: "Visite des locaux & présentation équipe", task_type: "manual",       assigned_to_role: "manager",  due_day_offset: 1,  position: 2 },
          { title: "Accès Figma, Notion, Slack",             task_type: "manual",        assigned_to_role: "hr",       due_day_offset: 1,  position: 3 },
          { title: "Formation Figma avancé",                 task_type: "training",      assigned_to_role: "employee", due_day_offset: 7,  position: 4 },
          { title: "Objectif J+30 — premier livrable",       task_type: "objective_30",  assigned_to_role: "manager",  due_day_offset: 30, position: 5 },
          { title: "1:1 bilan mi-parcours",                  task_type: "one_on_one",    assigned_to_role: "manager",  due_day_offset: 45, position: 6 },
          { title: "Objectif J+60 — intégration process",    task_type: "objective_60",  assigned_to_role: "manager",  due_day_offset: 60, position: 7 },
          { title: "Objectif J+90 — autonomie complète",     task_type: "objective_90",  assigned_to_role: "manager",  due_day_offset: 90, position: 8 },
        ].each do |t|
          OnboardingTemplateTask.create!(t.merge(onboarding_template: tpl_design, organization: org))
        end

        tpl_tech = OnboardingTemplate.create!(
          organization: org, name: "Intégration Tech", duration_days: 60, active: true,
          description: "Parcours pour les développeurs et profils techniques"
        )
        [
          { title: "Setup poste + accès GitHub / VS Code",   task_type: "manual",        assigned_to_role: "manager",  due_day_offset: 0,  position: 1 },
          { title: "Lecture doc technique & architecture",    task_type: "manual",        assigned_to_role: "employee", due_day_offset: 2,  position: 2 },
          { title: "Formation Notion équipe",                 task_type: "training",      assigned_to_role: "employee", due_day_offset: 5,  position: 3 },
          { title: "Première PR mergée",                      task_type: "objective_30",  assigned_to_role: "employee", due_day_offset: 14, position: 4 },
          { title: "1:1 fin de période d'essai",              task_type: "one_on_one",    assigned_to_role: "manager",  due_day_offset: 30, position: 5 },
          { title: "Autonomie feature complète",              task_type: "objective_60",  assigned_to_role: "manager",  due_day_offset: 60, position: 6 },
        ].each do |t|
          OnboardingTemplateTask.create!(t.merge(onboarding_template: tpl_tech, organization: org))
        end

        # -----------------------------------------------------------------------
        puts "🚀 Onboardings actifs..."
        # Manon (Marketing, arrivée il y a 6 mois — onboarding en cours)
        onboarding_manon = EmployeeOnboarding.create!(
          organization: org, employee: manon, manager: manager,
          onboarding_template: tpl_design,
          start_date: manon.start_date, end_date: manon.start_date + 90.days,
          status: "active"
        )
        [
          { title: "Remise du matériel + accès outils",     task_type: "manual",       assigned_to_role: "manager",  due_date: manon.start_date,      status: "completed", completed_at: manon.start_date + 1.day },
          { title: "Visite des locaux & présentation équipe", task_type: "manual",     assigned_to_role: "manager",  due_date: manon.start_date + 1,  status: "completed", completed_at: manon.start_date + 2.days },
          { title: "Accès Figma, Notion, Slack",            task_type: "manual",       assigned_to_role: "hr",       due_date: manon.start_date + 1,  status: "completed", completed_at: manon.start_date + 1.day },
          { title: "Formation Figma avancé",                task_type: "training",     assigned_to_role: "employee", due_date: manon.start_date + 7,  status: "completed", completed_at: manon.start_date + 10.days },
          { title: "Objectif J+30 — premier livrable",      task_type: "objective_30", assigned_to_role: "manager",  due_date: manon.start_date + 30, status: "completed", completed_at: manon.start_date + 32.days },
          { title: "1:1 bilan mi-parcours",                 task_type: "one_on_one",   assigned_to_role: "manager",  due_date: manon.start_date + 45, status: "completed", completed_at: manon.start_date + 45.days },
          { title: "Objectif J+60 — intégration process",   task_type: "objective_60", assigned_to_role: "manager",  due_date: manon.start_date + 60, status: "completed", completed_at: manon.start_date + 62.days },
          { title: "Objectif J+90 — autonomie complète",    task_type: "objective_90", assigned_to_role: "manager",  due_date: manon.start_date + 90, status: "completed", completed_at: manon.start_date + 90.days },
        ].each do |t|
          OnboardingTask.create!(t.merge(
            organization: org, employee_onboarding: onboarding_manon,
            completed_by: t[:status] == "completed" ? manager : nil
          ))
        end

        # Thomas (Tech, arrivé il y a 14 mois — montrons un onboarding terminé)
        onboarding_thomas = EmployeeOnboarding.create!(
          organization: org, employee: thomas, manager: manager,
          onboarding_template: tpl_tech,
          start_date: thomas.start_date, end_date: thomas.start_date + 60.days,
          status: "completed"
        )
        [
          { title: "Setup poste + accès GitHub / VS Code",  task_type: "manual",       assigned_to_role: "manager",  due_date: thomas.start_date,      status: "completed", completed_at: thomas.start_date + 1.day },
          { title: "Lecture doc technique & architecture",  task_type: "manual",       assigned_to_role: "employee", due_date: thomas.start_date + 2,  status: "completed", completed_at: thomas.start_date + 3.days },
          { title: "Formation Notion équipe",               task_type: "training",     assigned_to_role: "employee", due_date: thomas.start_date + 5,  status: "completed", completed_at: thomas.start_date + 6.days },
          { title: "Première PR mergée",                    task_type: "objective_30", assigned_to_role: "employee", due_date: thomas.start_date + 14, status: "completed", completed_at: thomas.start_date + 12.days },
          { title: "1:1 fin de période d'essai",            task_type: "one_on_one",   assigned_to_role: "manager",  due_date: thomas.start_date + 30, status: "completed", completed_at: thomas.start_date + 30.days },
          { title: "Autonomie feature complète",            task_type: "objective_60", assigned_to_role: "manager",  due_date: thomas.start_date + 60, status: "completed", completed_at: thomas.start_date + 58.days },
        ].each do |t|
          OnboardingTask.create!(t.merge(
            organization: org, employee_onboarding: onboarding_thomas,
            completed_by: manager
          ))
        end
      end

      # -----------------------------------------------------------------------
      puts "🎯 Objectifs..."
      ActsAsTenant.with_tenant(org) do
        Objective.create!(organization: org, manager_id: manager.id, created_by: manager,
          owner: camille, title: "Lancer le site v2 avant fin Q2",
          description: "Coordonner les équipes design et tech pour la mise en ligne",
          status: "in_progress", priority: "high", deadline: 2.months.from_now.to_date)

        Objective.create!(organization: org, manager_id: manager.id, created_by: manager,
          owner: sophie, title: "Refonte du design system — composants v2",
          description: "Documenter et migrer tous les composants vers Figma variables",
          status: "in_progress", priority: "medium", deadline: 6.weeks.from_now.to_date)

        Objective.create!(organization: org, manager_id: manager.id, created_by: manager,
          owner: antoine, title: "Produire 3 vidéos motion pour la campagne été",
          description: "Spots animés pour Instagram, LinkedIn et le site",
          status: "in_progress", priority: "high", deadline: 5.weeks.from_now.to_date)

        Objective.create!(organization: org, manager_id: manager.id, created_by: manager,
          owner: thomas, title: "Migrer le front vers Vite + TypeScript",
          description: "Réduire le build time et améliorer la DX",
          status: "draft", priority: "low", deadline: 3.months.from_now.to_date)

        Objective.create!(organization: org, manager_id: manager.id, created_by: manager,
          owner: manon, title: "Atteindre 500 abonnés newsletter d'ici fin T2",
          description: "Plan éditorial hebdomadaire + campagne de relance",
          status: "in_progress", priority: "medium", deadline: 2.months.from_now.to_date)
      end

      # -----------------------------------------------------------------------
      puts "💬 1:1s planifiés et passés..."
      ActsAsTenant.with_tenant(org) do
        # Passés
        OneOnOne.create!(organization: org, manager_id: manager.id, employee_id: antoine.id,
          scheduled_at: 3.weeks.ago.to_time + 14.hours, status: "completed",
          completed_at: 3.weeks.ago, agenda: "Bilan Q4, charge de travail, outils",
          notes: "Antoine est motivé. Souhaite explorer l'animation 3D.")

        OneOnOne.create!(organization: org, manager_id: manager.id, employee_id: thomas.id,
          scheduled_at: 2.weeks.ago.to_time + 10.hours, status: "completed",
          completed_at: 2.weeks.ago, agenda: "Point technique — stack front",
          notes: "Migration Vite validée, à planifier Q3.")

        OneOnOne.create!(organization: org, manager_id: manager.id, employee_id: camille.id,
          scheduled_at: 1.week.ago.to_time + 11.hours, status: "completed",
          completed_at: 1.week.ago, agenda: "Suivi projet site v2 — risques planning",
          notes: "Délai serré, besoin de renfort design côté Sophie.")

        # Planifiés
        OneOnOne.create!(organization: org, manager_id: manager.id, employee_id: antoine.id,
          scheduled_at: 3.days.from_now.to_time + 14.hours, status: "scheduled",
          agenda: "Bilan Q1, objectifs Q2, évolution de poste")

        OneOnOne.create!(organization: org, manager_id: manager.id, employee_id: sophie.id,
          scheduled_at: 5.days.from_now.to_time + 9.hours, status: "scheduled",
          agenda: "Design system v2 — avancement, blocages")

        OneOnOne.create!(organization: org, manager_id: manager.id, employee_id: manon.id,
          scheduled_at: 1.week.from_now.to_time + 15.hours, status: "scheduled",
          agenda: "Newsletter — bilan 1er mois, stratégie contenu Q2")
      end

      puts ""
      puts "✅ Org Manager OS prête !"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "  URL        : http://localhost:3000"
      puts "  Email      : lucas.martin@studio-demo.fr"
      puts "  Password   : password123"
      puts "  Plan       : Manager OS (6 membres inclus, 5/6 utilisés)"
      puts "  Équipe     : 5 collaborateurs"
      puts "  Templates  : 2 (Intégration Designer, Intégration Tech)"
      puts "  Onboardings: 2 (Manon actif/complété, Thomas terminé)"
      puts "  Formations : 3 (Figma, Notion, After Effects)"
      puts "  Objectifs  : 5"
      puts "  1:1s       : 6 (3 passés, 3 planifiés)"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    end
  end
end
