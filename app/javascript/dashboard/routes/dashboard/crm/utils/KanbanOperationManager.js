export class KanbanOperationManager {
  constructor(logger) {
    this.operations = new Map();
    this.logger = logger;
    this.operationRegistry = {};
    this.pendingOperations = new Set();
    this.completedOperations = new Set();
    this.failedOperations = new Set();
    this.recentOperations = new Map();
    this.MAX_OPERATION_HISTORY = 50;
  }

  registerOperation(cardId, columnId) {
    const operationId = `${cardId}-${Date.now()}`;
    
    // Verificar se já existe uma operação pendente para este card
    if (this.isOperationPending(cardId)) {
      this.logger.log('warn', 'Tentativa de registrar operação para card com operação pendente', {
        cardId, columnId, existingOps: this.getCardOperations(cardId)
      });
      return null;
    }
    
    // Verificar operações recentes para este card (prevenção de spam)
    const recentKey = `${cardId}-${columnId}`;
    const now = Date.now();
    if (this.recentOperations.has(recentKey)) {
      const lastOpTime = this.recentOperations.get(recentKey);
      if (now - lastOpTime < 5000) { // 5 segundos
        this.logger.log('warn', 'Operação muito recente, ignorando', {
          cardId, columnId, timeSinceLast: now - lastOpTime
        });
        return null;
      }
    }
    
    // Registrar no mapa de operações recentes
    this.recentOperations.set(recentKey, now);
    if (this.recentOperations.size > this.MAX_OPERATION_HISTORY) {
      // Remover a entrada mais antiga
      const oldestKey = this.recentOperations.keys().next().value;
      this.recentOperations.delete(oldestKey);
    }
    
    // Adicionar ao registro de operações pendentes
    this.pendingOperations.add(cardId);
    
    // Registrar operação
    this.operations.set(operationId, {
      cardId,
      columnId,
      timestamp: now,
      status: 'pending'
    });
    
    // Registrar no cache de operações para evitar duplicações
    this.operationRegistry[recentKey] = operationId;
    
    // Auto-limpeza após 30 segundos
    setTimeout(() => {
      this.operations.delete(operationId);
      this.pendingOperations.delete(cardId);
      delete this.operationRegistry[recentKey];
    }, 30000);

    this.logger.log('info', 'Operação registrada', {
      operationId, cardId, columnId
    });
    
    return operationId;
  }

  completeOperation(operationId, success = true) {
    const operation = this.operations.get(operationId);
    if (!operation) {
      this.logger.log('warn', 'Tentativa de completar operação inexistente', { operationId });
      return false;
    }
    
    operation.status = success ? 'completed' : 'failed';
    operation.completedAt = Date.now();
    
    // Remover do conjunto de operações pendentes
    this.pendingOperations.delete(operation.cardId);
    
    // Adicionar ao conjunto apropriado
    if (success) {
      this.completedOperations.add(operation.cardId);
    } else {
      this.failedOperations.add(operation.cardId);
    }
    
    // Auto-limpeza após 10 segundos
    setTimeout(() => {
      this.completedOperations.delete(operation.cardId);
      this.failedOperations.delete(operation.cardId);
    }, 10000);
    
    this.logger.log(
      success ? 'info' : 'error',
      `Operação ${operationId} ${success ? 'completada' : 'falhou'}`,
      operation
    );
    
    return true;
  }

  isOperationPending(cardId) {
    return this.pendingOperations.has(cardId);
  }
  
  hasOperationFailed(cardId) {
    return this.failedOperations.has(cardId);
  }
  
  getCardOperations(cardId) {
    return Array.from(this.operations.values())
      .filter(op => op.cardId === cardId);
  }

  getOperation(operationId) {
    return this.operations.get(operationId);
  }
  
  isOperationRegistered(cardId, columnId) {
    const key = `${cardId}-${columnId}`;
    return this.operationRegistry[key] !== undefined;
  }

  clearOperations() {
    this.operations.clear();
    this.pendingOperations.clear();
    this.completedOperations.clear();
    this.failedOperations.clear();
    this.recentOperations.clear();
    this.operationRegistry = {};
  }
} 