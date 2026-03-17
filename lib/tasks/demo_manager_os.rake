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
        # Détruire dans le bon ordre
        ActsAsTenant.with_tenant(existing) do
          [
            OnboardingTask, OnboardingReview, EmployeeOnboarding,
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
          "work_week_hours"    => 35,
          "rtt_enabled"        => false,
          "cp_acquisition_rate" => 2.5
        }
      )

      Subscription.create!(
        organization:    org,
        plan:            "manager_os",
        status:          "active",
        stripe_customer_id:      "cus_demo_manager_os",
        stripe_subscription_id:  "sub_demo_manager_os",
        commitment_end_at: 12.months.from_now
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
      team = [
        { first_name: "Sophie",   last_name: "Dubois",   job_title: "Designer UI/UX",      department: "Design",      start_date: 18.months.ago.to_date, cp: 12.0, cp_used: 3.0 },
        { first_name: "Thomas",   last_name: "Bernard",  job_title: "Développeur Front",    department: "Tech",        start_date: 14.months.ago.to_date, cp: 10.0, cp_used: 5.0 },
        { first_name: "Camille",  last_name: "Petit",    job_title: "Chef de Projet",       department: "Production",  start_date: 8.months.ago.to_date,  cp: 6.0,  cp_used: 0.0 },
        { first_name: "Antoine",  last_name: "Leroy",    job_title: "Motion Designer",      department: "Design",      start_date: 22.months.ago.to_date, cp: 20.0, cp_used: 10.0 },
        { first_name: "Manon",    last_name: "Garcia",   job_title: "Chargée de Comm.",     department: "Marketing",   start_date: 6.months.ago.to_date,  cp: 4.0,  cp_used: 0.0 }
      ]

      team.each do |attrs|
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

        LeaveBalance.create!(
          organization: org,
          employee:     emp,
          leave_type:   "CP",
          balance:      attrs[:cp],
          used_this_year: attrs[:cp_used]
        )
      end

      puts "📅 Création de quelques demandes de congés..."
      ActsAsTenant.with_tenant(org) do
        sophie = Employee.find_by(email: "sophie.dubois@studio-demo.fr")
        thomas = Employee.find_by(email: "thomas.bernard@studio-demo.fr")

        LeaveRequest.create!(
          organization: org,
          employee:     sophie,
          leave_type:   "CP",
          start_date:   2.weeks.from_now.to_date,
          end_date:     2.weeks.from_now.to_date + 4.days,
          days_count:   5,
          status:       "pending",
          reason:       "Vacances d'été anticipées"
        )

        LeaveRequest.create!(
          organization: org,
          employee:     thomas,
          leave_type:   "CP",
          start_date:   1.week.ago.to_date,
          end_date:     1.week.ago.to_date + 2.days,
          days_count:   3,
          status:       "approved",
          approved_by:  manager,
          approved_at:  5.days.ago
        )
      end

      puts "🕐 Création d'entrées de temps récentes..."
      ActsAsTenant.with_tenant(org) do
        [manager, Employee.find_by(email: "sophie.dubois@studio-demo.fr")].each do |emp|
          3.times do |i|
            day = (i + 1).days.ago.to_date
            next if day.saturday? || day.sunday?
            TimeEntry.create!(
              organization:     org,
              employee:         emp,
              clock_in:         day.to_time + 9.hours,
              clock_out:        day.to_time + 18.hours,
              duration_minutes: 480
            )
          end
        end
      end

      puts "🎯 Création d'un objectif..."
      ActsAsTenant.with_tenant(org) do
        camille = Employee.find_by(email: "camille.petit@studio-demo.fr")
        Objective.create!(
          organization: org,
          manager_id:   manager.id,
          created_by:   manager,
          owner:        camille,
          title:        "Lancer le site v2 avant fin Q2",
          description:  "Coordonner les équipes design et tech pour la mise en ligne",
          status:       "in_progress",
          deadline:     2.months.from_now.to_date
        )
      end

      puts "💬 Création d'un 1:1 planifié..."
      ActsAsTenant.with_tenant(org) do
        antoine = Employee.find_by(email: "antoine.leroy@studio-demo.fr")
        OneOnOne.create!(
          organization: org,
          employee_id:  antoine.id,
          manager_id:   manager.id,
          scheduled_at: 3.days.from_now.to_time + 14.hours,
          status:       "scheduled",
          agenda:       "Bilan Q1, objectifs Q2, évolution de poste"
        )
      end

      puts ""
      puts "✅ Org Manager OS prête !"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "  URL        : http://localhost:3000"
      puts "  Email      : lucas.martin@studio-demo.fr"
      puts "  Password   : password123"
      puts "  Plan       : Manager OS (6 membres inclus, 5/6 utilisés)"
      puts "  Équipe     : 5 collaborateurs"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    end
  end
end
