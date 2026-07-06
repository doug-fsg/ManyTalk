# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflows::DestroyService do
  let(:account) { create(:account) }
  let(:workflow) { create(:workflow, account: account, active: true) }
  let(:conversation) { create(:conversation, account: account) }

  it 'destroys workflow with in-progress enrollments and step executions' do
    enrollment = create(:workflow_enrollment, workflow: workflow, conversation: conversation, status: 'active')
    create(:workflow_step_execution, workflow_enrollment: enrollment, status: 'scheduled')

    expect do
      described_class.new(workflow: workflow).perform
    end.to change(Workflow, :count).by(-1)
       .and change(WorkflowEnrollment, :count).by(-1)
       .and change(WorkflowStepExecution, :count).by(-1)
  end

  it 'destroys workflow with completed enrollments' do
    create(:workflow_enrollment, workflow: workflow, conversation: conversation, status: 'completed')

    expect do
      described_class.new(workflow: workflow).perform
    end.to change(Workflow, :count).by(-1)
       .and change(WorkflowEnrollment, :count).by(-1)
  end
end
