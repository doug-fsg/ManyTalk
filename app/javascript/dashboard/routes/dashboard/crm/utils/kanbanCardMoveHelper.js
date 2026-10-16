/**
 * Política de persistência ao mover/reordenar cards no kanban.
 * Interface estreita: stage change → entered_at; ordem visual → positions 0..n-1.
 */

/**
 * Só reinicia tempo na etapa quando o card muda de stage.
 * @param {string} sourceStage
 * @param {string} targetStage
 * @param {() => string} [now]
 * @returns {string|null}
 */
export function enteredAtForMove(sourceStage, targetStage, now = () => new Date().toISOString()) {
  if (sourceStage == null || targetStage == null) return null;
  if (String(sourceStage) === String(targetStage)) return null;
  return now();
}

/**
 * Monta payload de reorder: renumeração 0..n-1 por coluna afetada.
 * Não envia deal_value/metadata (evita overwrite). entered_at só no card movido se stage mudou.
 *
 * @param {Object} params
 * @param {string} params.sourceStage
 * @param {string} params.targetStage
 * @param {Array} params.sourceItems - itens da coluna origem APÓS o drag (já sem o card, se mudou de stage)
 * @param {Array} params.targetItems - itens da coluna destino APÓS o drag
 * @param {number|string} params.movedContactId
 * @param {string|null} params.enteredAt
 * @returns {Array<{contact_id: number|string, stage_id: string, position: number, entered_at?: string}>}
 */
export function buildColumnReorderPositions({
  sourceStage,
  targetStage,
  sourceItems = [],
  targetItems = [],
  movedContactId,
  enteredAt = null,
}) {
  const positions = [];

  const appendColumn = (items, stageId) => {
    if (!Array.isArray(items)) return;
    items.forEach((contact, index) => {
      if (!contact || contact.id == null) return;
      const entry = {
        contact_id: contact.id,
        stage_id: stageId,
        position: index,
      };
      if (
        enteredAt &&
        movedContactId != null &&
        Number(contact.id) === Number(movedContactId)
      ) {
        entry.entered_at = enteredAt;
      }
      positions.push(entry);
    });
  };

  if (String(sourceStage) === String(targetStage)) {
    appendColumn(targetItems, targetStage);
  } else {
    appendColumn(sourceItems, sourceStage);
    appendColumn(targetItems, targetStage);
  }

  return positions;
}

/**
 * Aplica position (e stage_id) localmente nos pipeline_positions dos itens.
 * @param {Array} items
 * @param {number|string} pipelineId
 * @param {string} stageId
 * @param {{ movedContactId?: number|string, enteredAt?: string|null }} [opts]
 */
export function applyLocalColumnPositions(items, pipelineId, stageId, opts = {}) {
  if (!Array.isArray(items)) return;

  const pipelineIdNum =
    typeof pipelineId === 'string' ? parseInt(pipelineId, 10) : pipelineId;
  const { movedContactId, enteredAt } = opts;

  items.forEach((contact, index) => {
    if (!contact.pipeline_positions || !Array.isArray(contact.pipeline_positions)) {
      return;
    }
    const position = contact.pipeline_positions.find(p => {
      const pId =
        typeof p.pipeline_id === 'string' ? parseInt(p.pipeline_id, 10) : p.pipeline_id;
      return pId === pipelineIdNum;
    });
    if (!position) return;

    position.position = index;
    position.stage_id = stageId;
    if (
      enteredAt &&
      movedContactId != null &&
      Number(contact.id) === Number(movedContactId)
    ) {
      position.entered_at = enteredAt;
    }
  });
}
