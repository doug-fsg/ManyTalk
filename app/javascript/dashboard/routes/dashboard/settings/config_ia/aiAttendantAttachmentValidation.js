import { tokenStatus } from './aiAttendantReferenceVariables';

export const collectAttachmentFields = (form, steps = []) => {
  const fields = [
    {
      tab: 'identity',
      anchorId: 'ia-field-agent_role',
      text: form.agent_role,
    },
    {
      tab: 'identity',
      anchorId: 'ia-field-agent_duties',
      text: form.agent_duties,
    },
    {
      tab: 'identity',
      anchorId: 'ia-field-agent_objective',
      text: form.agent_objective,
    },
  ];

  (steps || []).forEach((step, index) => {
    fields.push({
      tab: 'playbook',
      anchorId: `ia-field-step-${index}-instruction`,
      text: step.instruction,
    });
    fields.push({
      tab: 'playbook',
      anchorId: `ia-field-step-${index}-completion`,
      text: step.completion_criterion,
    });
  });

  fields.push(
    {
      tab: 'rules',
      anchorId: 'ia-field-company_context',
      text: form.company_context,
    },
    {
      tab: 'rules',
      anchorId: 'ia-field-topics_to_avoid',
      text: form.topics_to_avoid_text,
    },
    {
      tab: 'rules',
      anchorId: 'ia-field-handoff_message',
      text: form.handoff_customer_message,
    }
  );

  return fields;
};

export const findFirstUnlinkedAttachmentIssue = (form, steps, fileItems) => {
  const fields = collectAttachmentFields(form, steps);

  for (let index = 0; index < fields.length; index += 1) {
    const field = fields[index];
    const statuses = tokenStatus(field.text, fileItems);
    const broken = statuses.find(entry => !entry.linked);
    if (broken) {
      return {
        tab: field.tab,
        anchorId: field.anchorId,
        token: broken.token,
        fieldIndex: index,
      };
    }
  }

  return null;
};
