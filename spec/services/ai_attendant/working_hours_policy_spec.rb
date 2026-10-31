# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiAttendant::WorkingHoursPolicy do
  around do |example|
    Time.use_zone('America/Sao_Paulo') { example.run }
  end

  let(:inbox) { create(:inbox, timezone: 'America/Sao_Paulo', working_hours_enabled: true) }

  def allow?(schedule_mode:, at: Time.zone.now)
    described_class.allow?(inbox: inbox, schedule_mode: schedule_mode, at: at)
  end

  # Wednesday 2026-10-28: default inbox hours Mon–Fri 09:00–17:00 America/Sao_Paulo
  let(:open_at) { Time.zone.local(2026, 10, 28, 10, 0, 0) }
  let(:closed_at) { Time.zone.local(2026, 10, 28, 22, 0, 0) }

  describe '.allow?' do
    it 'returns true when schedule_mode is always' do
      travel_to closed_at do
        expect(allow?(schedule_mode: 'always')).to be true
      end
    end

    context 'when working_hours_enabled is false (treat as 24/7)' do
      let(:inbox) { create(:inbox, timezone: 'America/Sao_Paulo', working_hours_enabled: false) }

      it 'returns true for within_inbox_hours inside and outside clock hours' do
        travel_to open_at do
          expect(allow?(schedule_mode: 'within_inbox_hours')).to be true
        end
        travel_to closed_at do
          expect(allow?(schedule_mode: 'within_inbox_hours')).to be true
        end
      end

      it 'returns true for outside_inbox_hours inside and outside clock hours' do
        travel_to open_at do
          expect(allow?(schedule_mode: 'outside_inbox_hours')).to be true
        end
        travel_to closed_at do
          expect(allow?(schedule_mode: 'outside_inbox_hours')).to be true
        end
      end
    end

    it 'returns true when inbox is open and schedule_mode is within_inbox_hours' do
      travel_to open_at do
        expect(inbox.working_now?).to be true
        expect(allow?(schedule_mode: 'within_inbox_hours')).to be true
      end
    end

    it 'returns false when inbox is closed and schedule_mode is within_inbox_hours' do
      travel_to closed_at do
        expect(inbox.working_now?).to be false
        expect(allow?(schedule_mode: 'within_inbox_hours')).to be false
      end
    end

    it 'returns false when inbox is open and schedule_mode is outside_inbox_hours' do
      travel_to open_at do
        expect(allow?(schedule_mode: 'outside_inbox_hours')).to be false
      end
    end

    it 'returns true when inbox is closed and schedule_mode is outside_inbox_hours' do
      travel_to closed_at do
        expect(allow?(schedule_mode: 'outside_inbox_hours')).to be true
      end
    end
  end
end
