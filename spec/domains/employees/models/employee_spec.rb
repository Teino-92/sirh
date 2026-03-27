require 'rails_helper'

RSpec.describe Employee, type: :model do
  describe '#dashboard_layout_mobile' do
    let(:org)      { create(:organization) }
    let(:employee) { create(:employee, organization: org, role: 'employee') }

    it 'retourne un layout par défaut avec grid et hidden' do
      layout = employee.dashboard_layout_mobile
      expect(layout).to have_key('grid')
      expect(layout).to have_key('hidden')
      expect(layout['grid']).to be_an(Array)
      expect(layout['hidden']).to eq([])
    end

    it 'toutes les cards du layout mobile ont w=1' do
      layout = employee.dashboard_layout_mobile
      expect(layout['grid'].map { |c| c['w'] }).to all(eq(1))
    end

    it 'persiste un layout mobile sans affecter le layout desktop' do
      mobile = { 'grid' => [{ 'id' => 'leave_balances', 'x' => 0, 'y' => 0, 'w' => 1, 'h' => 3 }], 'hidden' => [] }
      employee.dashboard_layout_mobile = mobile
      employee.save!
      employee.reload
      expect(employee.dashboard_layout_mobile['grid'].first['id']).to eq('leave_balances')
      expect(employee.dashboard_layout['grid'].map { |c| c['id'] }).to include('leave_balances')
    end

    it 'le layout desktop reste inchangé quand on sauvegarde le mobile' do
      desktop_before = employee.dashboard_layout.deep_dup
      mobile = { 'grid' => [{ 'id' => 'quick_links', 'x' => 0, 'y' => 0, 'w' => 1, 'h' => 3 }], 'hidden' => [] }
      employee.dashboard_layout_mobile = mobile
      employee.save!
      employee.reload
      expect(employee.dashboard_layout['grid']).to eq(desktop_before['grid'])
    end
  end
end
