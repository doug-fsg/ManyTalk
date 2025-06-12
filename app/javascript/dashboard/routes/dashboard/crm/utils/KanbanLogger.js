export class KanbanLogger {
  static ERROR = 'error';
  static WARN = 'warn';
  static INFO = 'info';
  static DEBUG = 'debug';

  constructor(enabled = false) {
    this.enabled = enabled;
    this.logs = [];
    this.maxLogs = 100;
  }

  log(level, message, data = {}) {
    if (!this.enabled) return;

    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      data
    };

    this.logs.unshift(logEntry);
    if (this.logs.length > this.maxLogs) {
      this.logs.pop();
    }

    // Console log apenas em desenvolvimento
    if (process.env.NODE_ENV !== 'production') {
      console[level](`[Kanban] ${message}`, data);
    }
  }

  getLogs() {
    return [...this.logs];
  }

  clear() {
    this.logs = [];
  }
} 