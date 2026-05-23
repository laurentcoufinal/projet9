import { Injectable } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class TraceIdService {
  private currentId: string | null = null;

  generate(): string {
    return crypto.randomUUID();
  }

  getCurrentId(): string | null {
    return this.currentId;
  }

  runWithId<T>(requestId: string, fn: () => T | Promise<T>): T | Promise<T> {
    const previous = this.currentId;
    this.currentId = requestId;
    try {
      const result = fn();
      if (result instanceof Promise) {
        return result.finally(() => {
          this.currentId = previous;
        });
      }
      this.currentId = previous;
      return result;
    } catch (e) {
      this.currentId = previous;
      throw e;
    }
  }
}
