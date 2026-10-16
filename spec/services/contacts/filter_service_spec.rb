require 'rails_helper'

describe Contacts::FilterService do
  subject(:filter_service) { described_class }

  let!(:account) { create(:account) }
  let!(:first_user) { create(:user, account: account) }
  let!(:second_user) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let!(:en_contact) { create(:contact, account: account, additional_attributes: { 'country_code': 'uk' }) }
  let!(:el_contact) { create(:contact, account: account, additional_attributes: { 'country_code': 'gr' }) }
  let!(:cs_contact) { create(:contact, account: account, additional_attributes: { 'country_code': 'cz' }) }

  before do
    create(:inbox_member, user: first_user, inbox: inbox)
    create(:inbox_member, user: second_user, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, assignee: first_user, contact: en_contact)
    create(:conversation, account: account, inbox: inbox, contact: el_contact)

    create(:custom_attribute_definition,
           attribute_key: 'contact_additional_information',
           account: account,
           attribute_model: 'contact_attribute',
           attribute_display_type: 'text')
    create(:custom_attribute_definition,
           attribute_key: 'customer_type',
           account: account,
           attribute_model: 'contact_attribute',
           attribute_display_type: 'list',
           attribute_values: %w[regular platinum gold])
    create(:custom_attribute_definition,
           attribute_key: 'signed_in_at',
           account: account,
           attribute_model: 'contact_attribute',
           attribute_display_type: 'date')
  end

  describe '#perform' do
    let!(:params) { { payload: [], page: 1 } }

    before do
      en_contact.update_labels(%w[random_label support])
      cs_contact.update_labels('support')

      en_contact.update!(custom_attributes: { contact_additional_information: 'test custom data' })
      el_contact.update!(custom_attributes: { contact_additional_information: 'test custom data', customer_type: 'platinum' })
      cs_contact.update!(custom_attributes: { customer_type: 'platinum', signed_in_at: '2022-01-19' })
    end

    context 'with standard attributes - name' do
      it 'filter contacts by name' do
        params[:payload] = [
          {
            attribute_key: 'name',
            filter_operator: 'equal_to',
            values: [en_contact.name],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        expect(result[:count]).to be 1
        expect(result[:contacts].length).to be 1
        expect(result[:contacts].first.name).to eq(en_contact.name)
      end
    end

    context 'with standard attributes - blocked' do
      it 'filter contacts by blocked' do
        blocked_contact = create(:contact, account: account, blocked: true)
        params = { payload: [{ attribute_key: 'blocked', filter_operator: 'equal_to', values: ['true'],
                               query_operator: nil }.with_indifferent_access] }
        result = filter_service.new(account, first_user, params).perform
        expect(result[:count]).to be 1
        expect(result[:contacts].first.id).to eq(blocked_contact.id)
      end

      it 'filter contacts by not_blocked' do
        params = { payload: [{ attribute_key: 'blocked', filter_operator: 'equal_to', values: [false],
                               query_operator: nil }.with_indifferent_access] }
        result = filter_service.new(account, first_user, params).perform
        # existing contacts are not blocked
        expect(result[:count]).to be 3
      end
    end

    context 'with standard attributes - label' do
      it 'returns equal_to filter results properly' do
        params[:payload] = [
          {
            attribute_key: 'labels',
            filter_operator: 'equal_to',
            values: ['support'],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be 2
        expect(result[:contacts].first.label_list).to include('support')
        expect(result[:contacts].last.label_list).to include('support')
      end

      it 'returns not_equal_to filter results properly' do
        params[:payload] = [
          {
            attribute_key: 'labels',
            filter_operator: 'not_equal_to',
            values: ['support'],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be 1
        expect(result[:contacts].first.id).to eq el_contact.id
      end

      it 'returns is_present filter results properly' do
        params[:payload] = [
          {
            attribute_key: 'labels',
            filter_operator: 'is_present',
            values: [],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be 2
        expect(result[:contacts].first.label_list).to include('support')
        expect(result[:contacts].last.label_list).to include('support')
      end

      it 'returns is_not_present filter results properly' do
        params[:payload] = [
          {
            attribute_key: 'labels',
            filter_operator: 'is_not_present',
            values: [],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be 1
        expect(result[:contacts].first.id).to eq el_contact.id
      end
    end

    context 'with standard attributes - last_activity_at' do
      before do
        Time.zone = 'UTC'
        el_contact.update(last_activity_at: (Time.zone.today - 4.days))
        cs_contact.update(last_activity_at: (Time.zone.today - 5.days))
        en_contact.update(last_activity_at: (Time.zone.today - 2.days))
      end

      it 'filter by last_activity_at 3_days_before and custom_attributes' do
        params[:payload] = [
          {
            attribute_key: 'last_activity_at',
            filter_operator: 'days_before',
            values: [3],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'contact_additional_information',
            filter_operator: 'equal_to',
            values: ['test custom data'],
            query_operator: nil
          }.with_indifferent_access
        ]

        expected_count = Contact.where(
          "last_activity_at < ? AND
          custom_attributes->>'contact_additional_information' = ?",
          (Time.zone.today - 3.days),
          'test custom data'
        ).count

        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be expected_count
        expect(result[:contacts].first.id).to eq(el_contact.id)
      end

      it 'filter by last_activity_at 2_days_before and custom_attributes' do
        params[:payload] = [
          {
            attribute_key: 'last_activity_at',
            filter_operator: 'days_before',
            values: [2],
            query_operator: nil
          }.with_indifferent_access
        ]

        expected_count = Contact.where('last_activity_at < ?', (Time.zone.today - 2.days)).count

        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be expected_count
        expect(result[:contacts].pluck(:id)).to include(el_contact.id)
        expect(result[:contacts].pluck(:id)).to include(cs_contact.id)
        expect(result[:contacts].pluck(:id)).not_to include(en_contact.id)
      end
    end

    context 'with additional attributes' do
      let(:payload) do
        [
          {
            attribute_key: 'country_code',
            filter_operator: 'equal_to',
            values: ['uk'],
            query_operator: nil
          }.with_indifferent_access
        ]
      end

      it 'filter contacts by additional_attributes' do
        params[:payload] = payload
        result = filter_service.new(account, first_user, params).perform
        expect(result[:count]).to be 1
        expect(result[:contacts].first.id).to eq(en_contact.id)
      end
    end

    context 'with custom attributes' do
      it 'filter by custom_attributes and labels' do
        params[:payload] = [
          {
            attribute_key: 'customer_type',
            filter_operator: 'equal_to',
            values: ['platinum'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'labels',
            filter_operator: 'equal_to',
            values: ['support'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'signed_in_at',
            filter_operator: 'is_less_than',
            values: ['2022-01-20'],
            query_operator: nil
          }.with_indifferent_access
        ]
        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be 1
        expect(result[:contacts].first.id).to eq(cs_contact.id)
      end

      it 'filter by custom_attributes and additional_attributes' do
        params[:payload] = [
          {
            attribute_key: 'customer_type',
            filter_operator: 'equal_to',
            values: ['platinum'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'country_code',
            filter_operator: 'equal_to',
            values: ['GR'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'contact_additional_information',
            filter_operator: 'equal_to',
            values: ['test custom data'],
            query_operator: nil
          }.with_indifferent_access
        ]
        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].length).to be 1
        expect(result[:contacts].first.id).to eq(el_contact.id)
      end

      it 'filter by created_at and custom_attributes' do
        tomorrow = Date.tomorrow.strftime
        params[:payload] = [
          {
            attribute_key: 'customer_type',
            filter_operator: 'equal_to',
            values: ['platinum'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: 'created_at',
            filter_operator: 'is_less_than',
            values: [tomorrow.to_s],
            query_operator: nil
          }.with_indifferent_access
        ]
        result = filter_service.new(account, first_user, params).perform
        expected_count = Contact.where("created_at < ? AND custom_attributes->>'customer_type' = ?", Date.tomorrow, 'platinum').count

        expect(result[:contacts].length).to be expected_count
        expect(result[:contacts].pluck(:id)).to include(el_contact.id)
      end
    end

    context 'with pipeline position filters' do
      let!(:pipeline) { create(:custom_attribute_definition, :kanban, account: account, attribute_key: 'sales_funnel') }
      let!(:in_range_contact) { create(:contact, account: account, name: 'In Range') }
      let!(:out_of_range_contact) { create(:contact, account: account, name: 'Out Of Range') }
      let!(:won_contact) { create(:contact, account: account, name: 'Won Deal') }

      before do
        Time.zone = 'America/Sao_Paulo'
        create(:contact_pipeline_position,
               contact: in_range_contact,
               pipeline: pipeline,
               stage_id: 'Estágio 1',
               created_at: Time.zone.parse('2026-10-06 12:00:00'),
               deal_value: 100)
        create(:contact_pipeline_position,
               contact: out_of_range_contact,
               pipeline: pipeline,
               stage_id: 'Estágio 1',
               created_at: Time.zone.parse('2026-09-01 12:00:00'),
               deal_value: 50)
        create(:contact_pipeline_position,
               contact: won_contact,
               pipeline: pipeline,
               stage_id: 'Estágio 2',
               created_at: Time.zone.parse('2026-10-06 15:00:00'),
               deal_value: 200,
               metadata: { 'win_lost' => { 'status' => 'won' } })
      end

      def kanban_present_filter
        {
          attribute_key: 'sales_funnel',
          filter_operator: 'is_present',
          values: [],
          query_operator: 'AND'
        }.with_indifferent_access
      end

      it 'filters by pipeline created_at day range (inclusive local day)' do
        params[:payload] = [
          kanban_present_filter,
          {
            attribute_key: '_pipeline_created_at',
            filter_operator: 'is_greater_than',
            values: ['2026-10-06'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: '_pipeline_created_at',
            filter_operator: 'is_less_than',
            values: ['2026-10-06'],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        ids = result[:contacts].pluck(:id)

        expect(ids).to include(in_range_contact.id, won_contact.id)
        expect(ids).not_to include(out_of_range_contact.id)
      end

      it 'keeps YYYY-MM-DD day bounds in America/Sao_Paulo even when Time.zone is UTC' do
        Time.zone = 'UTC'
        # 06/10 22:00 BRT = 07/10 01:00 UTC — entra no dia civil BRT, não no dia UTC
        late_brt = create(:contact, account: account, name: 'Late BRT')
        create(:contact_pipeline_position,
               contact: late_brt,
               pipeline: pipeline,
               stage_id: 'Estágio 1',
               created_at: Time.find_zone('America/Sao_Paulo').parse('2026-10-06 22:00:00'))

        params[:payload] = [
          kanban_present_filter,
          {
            attribute_key: '_pipeline_created_at',
            filter_operator: 'is_greater_than',
            values: ['2026-10-06'],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: '_pipeline_created_at',
            filter_operator: 'is_less_than',
            values: ['2026-10-06'],
            query_operator: nil
          }.with_indifferent_access
        ]

        ids = filter_service.new(account, first_user, params).perform[:contacts].pluck(:id)
        expect(ids).to include(late_brt.id)
      end

      it 'filters by deal value range' do
        params[:payload] = [
          kanban_present_filter,
          {
            attribute_key: '_pipeline_deal_value',
            filter_operator: 'is_greater_than',
            values: [100],
            query_operator: 'AND'
          }.with_indifferent_access,
          {
            attribute_key: '_pipeline_deal_value',
            filter_operator: 'is_less_than',
            values: [200],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        ids = result[:contacts].pluck(:id)

        expect(ids).to include(in_range_contact.id, won_contact.id)
        expect(ids).not_to include(out_of_range_contact.id)
      end

      it 'filters by win_lost open status' do
        params[:payload] = [
          kanban_present_filter,
          {
            attribute_key: '_pipeline_win_lost',
            filter_operator: 'equal_to',
            values: ['open'],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        ids = result[:contacts].pluck(:id)

        expect(ids).to include(in_range_contact.id, out_of_range_contact.id)
        expect(ids).not_to include(won_contact.id)
      end

      it 'filters by win_lost won status' do
        params[:payload] = [
          kanban_present_filter,
          {
            attribute_key: '_pipeline_win_lost',
            filter_operator: 'equal_to',
            values: ['won'],
            query_operator: nil
          }.with_indifferent_access
        ]

        result = filter_service.new(account, first_user, params).perform
        expect(result[:contacts].pluck(:id)).to eq([won_contact.id])
      end
    end
  end
end
