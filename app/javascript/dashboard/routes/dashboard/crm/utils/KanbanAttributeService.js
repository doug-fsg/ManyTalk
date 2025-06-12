// Singleton para gerenciar operações de atributos personalizados
export class KanbanAttributeService {
  constructor(store, logger) {
    this.store = store;
    this.logger = logger;
    this.operationLocks = new Map();
    this.pendingOperations = new Map();
    this.recentUpdates = new Map();
    this.updateTimeout = 500; // ms
    this.blockingThreshold = 15000; // 15 segundos
    this.cycleLock = false;
    this.cycleLockTime = null;
  }

  // Método principal para atualizar atributos personalizados
  async updateContactAttribute(contactId, attributeKey, value, operationId) {
    // Verificar se a detecção de ciclo está ativa
    if (this.cycleLock) {
      const timeSinceLock = Date.now() - this.cycleLockTime;
      if (timeSinceLock < this.blockingThreshold) {
        this.logger.log('warn', 'Trava anti-ciclo ativa, operação bloqueada', {
          contactId,
          attributeKey,
          timeSinceLock,
          operationId,
        });
        return false;
      }
      // Se passou tempo suficiente, liberar a trava
      this.cycleLock = false;
      this.cycleLockTime = null;
    }

    if (this.operationLocks.has(contactId)) {
      this.logger.log('warn', 'Operação ignorada: contato bloqueado', {
        contactId,
        attributeKey,
        currentLock: this.operationLocks.get(contactId),
      });
      return false;
    }

    // Verificar por atualizações recentes para este mesmo valor
    const updateKey = `${contactId}-${attributeKey}-${value}`;
    if (this.recentUpdates.has(updateKey)) {
      const timeSinceLastUpdate =
        Date.now() - this.recentUpdates.get(updateKey);

      // Aumentar o tempo de bloqueio para 15 segundos para evitar ciclos
      if (timeSinceLastUpdate < this.blockingThreshold) {
        this.logger.log(
          'warn',
          'Operação ignorada: atualização recente detectada',
          {
            contactId,
            attributeKey,
            timeSinceLastUpdate,
          }
        );

        // Se esta é a terceira tentativa de atualização em curto período, ativar trava anti-ciclo
        const updateCount = this.getRecentUpdateCount(contactId, attributeKey);
        if (updateCount >= 3) {
          this.activateCycleLock();
        }

        return false;
      }
    }

    // Marcar como atualizado recentemente
    this.recentUpdates.set(updateKey, Date.now());

    // Adquirir lock
    this.operationLocks.set(contactId, {
      operationId,
      attributeKey,
      value,
      timestamp: Date.now(),
    });

    try {
      // Aplicar timeout para evitar atualizações muito rápidas
      await this.waitForTimeout();

      // Preparar payload da atualização
      const updatePayload = {
        id: contactId,
        custom_attributes: {
          [attributeKey]: value,
        },
        _fromKanban: true,
        _kanbanOperation: operationId,
        _kanbanUpdateTimestamp: Date.now(),
      };

      this.logger.log('info', 'Iniciando atualização de atributo', {
        contactId,
        attributeKey,
        value,
        operationId,
      });

      // Enviar atualização para o store
      await this.store.dispatch('contacts/update', updatePayload);

      this.logger.log('info', 'Atualização de atributo concluída', {
        contactId,
        attributeKey,
        operationId,
      });

      return true;
    } catch (error) {
      this.logger.log('error', 'Erro ao atualizar atributo', {
        contactId,
        attributeKey,
        error: error.message,
        operationId,
      });
      throw error;
    } finally {
      // Liberar lock após um tempo seguro para garantir que a UI foi atualizada
      setTimeout(() => {
        this.operationLocks.delete(contactId);
        this.logger.log('info', 'Lock liberado', { contactId, operationId });
      }, 2000);
    }
  }

  // Método para remover um atributo personalizado
  async removeContactAttribute(contactId, attributeKey, operationId) {
    if (this.operationLocks.has(contactId)) {
      this.logger.log('warn', 'Remoção ignorada: contato bloqueado', {
        contactId,
        attributeKey,
        currentLock: this.operationLocks.get(contactId),
      });
      return false;
    }

    // Adquirir lock
    this.operationLocks.set(contactId, {
      operationId,
      attributeKey,
      operation: 'remove',
      timestamp: Date.now(),
    });

    try {
      this.logger.log('info', 'Iniciando remoção de atributo', {
        contactId,
        attributeKey,
        operationId,
      });

      const updatePayload = {
        id: contactId,
        contact: {
          custom_attributes: {
            [attributeKey]: null,
          },
        },
        _fromKanban: true,
        _kanbanOperation: operationId,
      };

      // Enviar para o store
      await this.store.dispatch('contacts/update', updatePayload);

      this.logger.log('info', 'Remoção de atributo concluída', {
        contactId,
        attributeKey,
        operationId,
      });

      return true;
    } catch (error) {
      this.logger.log('error', 'Erro ao remover atributo', {
        contactId,
        attributeKey,
        error: error.message,
        operationId,
      });
      throw error;
    } finally {
      // Liberar lock após um tempo seguro
      setTimeout(() => {
        this.operationLocks.delete(contactId);
      }, 2000);
    }
  }

  // Método para ativar a trava anti-ciclo
  activateCycleLock() {
    this.cycleLock = true;
    this.cycleLockTime = Date.now();
    this.logger.log(
      'warn',
      '[KanbanAutoreset] Ciclo de atualizações detectado!',
      {
        time: new Date().toISOString(),
      }
    );

    // Auto-liberação após o tempo de bloqueio
    setTimeout(() => {
      this.cycleLock = false;
      this.cycleLockTime = null;
      this.logger.log('info', 'Trava anti-ciclo liberada automaticamente');
    }, this.blockingThreshold);
  }

  // Conta quantas atualizações recentes existem para um contato/atributo
  getRecentUpdateCount(contactId, attributeKey) {
    const threshold = Date.now() - this.blockingThreshold;
    let count = 0;

    // Contar todas as entradas recentes para este contato/atributo
    this.recentUpdates.forEach((timestamp, key) => {
      if (
        key.startsWith(`${contactId}-${attributeKey}`) &&
        timestamp > threshold
      ) {
        count += 1;
      }
    });

    return count;
  }

  // Método para liberar todos os locks (usado em casos extremos)
  clearAllLocks() {
    this.operationLocks.clear();
    this.pendingOperations.clear();
    this.cycleLock = false;
    this.cycleLockTime = null;
    this.logger.log('warn', 'Todos os locks foram limpos');
  }

  // Verificar se um contato tem lock
  hasLock(contactId) {
    return this.operationLocks.has(contactId);
  }

  // Retorna informações do lock atual
  getLockInfo(contactId) {
    return this.operationLocks.get(contactId);
  }

  // Método interno para aguardar um timeout antes de continuar
  waitForTimeout() {
    return new Promise(resolve => {
      setTimeout(resolve, this.updateTimeout);
    });
  }

  // Limpar dados de atualizações recentes (usado para casos específicos)
  clearRecentUpdates() {
    this.recentUpdates.clear();
  }
} 