# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Exports::PayrollSilaeCsvExporter, type: :service do
  let(:org) { create(:organization) }
  # hr requester is excluded from export results (settings active: false)
  let(:hr)  { create(:employee, organization: org, role: 'hr', settings: { active: false }) }

  let(:period) { Date.new(2026, 2, 1) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  def run
    described_class.new(hr, period).export
  end

  def parse_csv(content)
    # Strip UTF-8 BOM if present
    cleaned = content.sub("\uFEFF", '')
    CSV.parse(cleaned, col_sep: ';', headers: true)
  end

  # ── Empty org ────────────────────────────────────────────────────────────────

  describe 'with no active employees' do
    it 'returns a CSV with only headers' do
      result = run
      rows   = parse_csv(result[:content])
      expect(rows.count).to eq(0)
    end

    it 'returns a filename matching silae_YYYY-MM_* pattern' do
      result = run
      expect(result[:filename]).to match(/\Asilae_2026-02_\d{8}_\d{4}\.csv\z/)
    end
  end

  # ── Row count ────────────────────────────────────────────────────────────────

  describe 'with active employees' do
    let!(:emp1) { create(:employee, organization: org, settings: { active: true }) }
    let!(:emp2) { create(:employee, organization: org, settings: { active: true }) }
    let!(:inactive) do
      create(:employee, organization: org, settings: { active: false })
    end

    before do
      create(:work_schedule, :full_time_35h, organization: org, employee: emp1)
      create(:work_schedule, :full_time_35h, organization: org, employee: emp2)
    end

    it 'exports one row per active employee' do
      rows = parse_csv(run[:content])
      expect(rows.count).to eq(2)
    end

    it 'does not export inactive employees' do
      rows     = parse_csv(run[:content])
      exported = rows.map { |r| r['Matricule'] }
      expect(exported).not_to include(inactive.id.to_s)
    end
  end

  # ── Header completeness ──────────────────────────────────────────────────────

  describe 'CSV headers' do
    it 'includes all 29 required Silae columns' do
      result  = run
      rows    = parse_csv(result[:content])
      headers = rows.headers
      expect(headers).to include(
        'Matricule', 'NIR', 'Nom', 'Prénom',
        'IBAN', 'BIC',
        'Salaire brut mensuel (€)',
        'Heures contractuelles / mois',
        'Heures pointées / mois',
        'Heures sup 25%', 'Heures sup 50%',
        'Jours CP pris', 'Jours RTT pris',
        'Jours maladie', 'Jours sans solde',
        'Cadre', 'Manager'
      )
      expect(headers.count).to eq(29)
    end
  end

  # ── Sensitive data presence ──────────────────────────────────────────────────

  describe 'sensitive data in export' do
    let!(:emp) do
      create(:employee,
             organization: org,
             nir:          '1750312345678',   # 13 digits, starts with 1
             iban:         'FR7630006000011234567890189',
             bic:          'BNPAFRPP',
             settings:     { active: true })
    end

    before do
      create(:work_schedule, :full_time_35h, organization: org, employee: emp)
    end

    it 'includes NIR in clear text' do
      rows = parse_csv(run[:content])
      row  = rows.find { |r| r['Matricule'] == emp.id.to_s }
      expect(row['NIR']).to eq('1750312345678')
    end

    it 'includes IBAN in clear text' do
      rows = parse_csv(run[:content])
      row  = rows.find { |r| r['Matricule'] == emp.id.to_s }
      expect(row['IBAN']).to eq('FR7630006000011234567890189')
    end

    it 'includes BIC' do
      rows = parse_csv(run[:content])
      row  = rows.find { |r| r['Matricule'] == emp.id.to_s }
      expect(row['BIC']).to eq('BNPAFRPP')
    end
  end

  # ── Cadre column ────────────────────────────────────────────────────────────

  describe 'Cadre column' do
    let!(:cadre_emp) do
      create(:employee, organization: org, settings: { active: true, cadre: true })
    end
    let!(:non_cadre_emp) do
      create(:employee, organization: org, settings: { active: true })
    end

    before do
      create(:work_schedule, :full_time_35h, organization: org, employee: cadre_emp)
      create(:work_schedule, :full_time_35h, organization: org, employee: non_cadre_emp)
    end

    it 'marks cadre employees as Oui' do
      rows = parse_csv(run[:content])
      row  = rows.find { |r| r['Matricule'] == cadre_emp.id.to_s }
      expect(row['Cadre']).to eq('Oui')
    end

    it 'marks non-cadre employees as Non' do
      rows = parse_csv(run[:content])
      row  = rows.find { |r| r['Matricule'] == non_cadre_emp.id.to_s }
      expect(row['Cadre']).to eq('Non')
    end
  end

  # ── Tenant isolation ─────────────────────────────────────────────────────────

  describe 'tenant isolation' do
    let(:org_b)  { create(:organization) }
    let!(:own)   { create(:employee, organization: org, settings: { active: true }) }
    let!(:other) { ActsAsTenant.with_tenant(org_b) { create(:employee, organization: org_b, settings: { active: true }) } }

    before do
      create(:work_schedule, :full_time_35h, organization: org, employee: own)
    end

    it 'does not include employees from another organization' do
      rows     = parse_csv(run[:content])
      exported = rows.map { |r| r['Matricule'] }
      expect(exported).not_to include(other.id.to_s)
      expect(exported).to     include(own.id.to_s)
    end
  end

  # ── Leave days reflected in CSV ──────────────────────────────────────────────

  describe 'leave days in export row' do
    let!(:emp) { create(:employee, organization: org, settings: { active: true }) }

    before do
      create(:work_schedule, :full_time_35h, organization: org, employee: emp)
      create(:leave_request,
             employee:     emp,
             organization: org,
             leave_type:   'CP',
             status:       'approved',
             days_count:   3.0,
             start_date:   period,
             end_date:     period + 4.days)
    end

    it 'reflects approved CP days in the Jours CP pris column' do
      rows = parse_csv(run[:content])
      row  = rows.find { |r| r['Matricule'] == emp.id.to_s }
      # CSV uses French decimal separator (comma)
      expect(row['Jours CP pris'].sub(',', '.').to_f).to eq(3.0)
    end
  end

  # ── Decimal format ───────────────────────────────────────────────────────────

  describe 'decimal format' do
    let!(:emp) do
      create(:employee,
             organization:       org,
             gross_salary_cents: 350_000,
             settings:           { active: true })
    end

    before do
      create(:work_schedule, :full_time_35h, organization: org, employee: emp)
    end

    it 'uses comma as decimal separator in numeric columns' do
      rows = parse_csv(run[:content])
      row  = rows.find { |r| r['Matricule'] == emp.id.to_s }
      expect(row['Salaire brut mensuel (€)']).to match(/\d+,\d{2}/)
    end
  end
end
