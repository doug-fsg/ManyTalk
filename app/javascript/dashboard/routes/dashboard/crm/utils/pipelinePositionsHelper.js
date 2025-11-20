/**
 * Helper functions para ler dados de pipeline_positions do contato
 * Todas as funções leem do array contact.pipeline_positions
 */

/**
 * Encontra a posição do pipeline para um contato
 * @param {Object} contact - Objeto do contato
 * @param {number|string} pipelineId - ID do pipeline
 * @returns {Object|null} - Objeto da posição ou null se não encontrado
 */
export function getPipelinePosition(contact, pipelineId) {
  if (!contact || !contact.pipeline_positions || !Array.isArray(contact.pipeline_positions)) {
    return null;
  }

  const pipelineIdNum = typeof pipelineId === 'string' ? parseInt(pipelineId, 10) : pipelineId;

  return contact.pipeline_positions.find(p => {
    const pPipelineId = typeof p.pipeline_id === 'string' ? parseInt(p.pipeline_id, 10) : p.pipeline_id;
    return pPipelineId === pipelineIdNum;
  }) || null;
}

/**
 * Retorna o stage_id do pipeline para um contato
 * @param {Object} contact - Objeto do contato
 * @param {number|string} pipelineId - ID do pipeline
 * @returns {string|null} - stage_id ou null se não encontrado
 */
export function getStage(contact, pipelineId) {
  const position = getPipelinePosition(contact, pipelineId);
  return position?.stage_id || null;
}

/**
 * Retorna o deal_value do pipeline para um contato
 * @param {Object} contact - Objeto do contato
 * @param {number|string} pipelineId - ID do pipeline
 * @returns {number|null} - deal_value ou null se não encontrado
 */
export function getDealValue(contact, pipelineId) {
  const position = getPipelinePosition(contact, pipelineId);
  return position?.deal_value != null ? parseFloat(position.deal_value) : null;
}

/**
 * Retorna os metadata do pipeline para um contato
 * @param {Object} contact - Objeto do contato
 * @param {number|string} pipelineId - ID do pipeline
 * @returns {Object} - metadata ou objeto vazio se não encontrado
 */
export function getMetadata(contact, pipelineId) {
  const position = getPipelinePosition(contact, pipelineId);
  return position?.metadata || {};
}

/**
 * Retorna o entered_at do pipeline para um contato
 * @param {Object} contact - Objeto do contato
 * @param {number|string} pipelineId - ID do pipeline
 * @returns {string|null} - entered_at (ISO string) ou null se não encontrado
 */
export function getEnteredAt(contact, pipelineId) {
  const position = getPipelinePosition(contact, pipelineId);
  return position?.entered_at || null;
}

/**
 * Retorna a position (ordem) do pipeline para um contato
 * @param {Object} contact - Objeto do contato
 * @param {number|string} pipelineId - ID do pipeline
 * @returns {number|null} - position ou null se não encontrado
 */
export function getPosition(contact, pipelineId) {
  const position = getPipelinePosition(contact, pipelineId);
  return position?.position != null ? parseInt(position.position, 10) : null;
}

/**
 * Retorna o win_lost status do pipeline para um contato
 * @param {Object} contact - Objeto do contato
 * @param {number|string} pipelineId - ID do pipeline
 * @returns {Object|null} - win_lost object ou null se não encontrado
 */
export function getWinLostStatus(contact, pipelineId) {
  const metadata = getMetadata(contact, pipelineId);
  return metadata?.win_lost || null;
}

