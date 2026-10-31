import { findFirstUnlinkedAttachmentIssue } from '../aiAttendantAttachmentValidation';

describe('aiAttendantAttachmentValidation', () => {
  const files = [{ tokenKey: 'catalogo', filename: 'catalogo.png' }];

  it('finds the first broken token and its field anchor', () => {
    const issue = findFirstUnlinkedAttachmentIssue(
      {
        agent_role: '',
        agent_duties: '',
        agent_objective: '',
        company_context: 'ok {{anexo:catalogo}}',
        topics_to_avoid_text: '',
        handoff_customer_message: '',
      },
      [{ instruction: 'envie {{anexo:5895c30be7bce75cc5318a08}}', completion_criterion: '' }],
      files
    );

    expect(issue.tab).toBe('playbook');
    expect(issue.anchorId).toBe('ia-field-step-0-instruction');
    expect(issue.token).toBe('{{anexo:5895c30be7bce75cc5318a08}}');
  });
});
