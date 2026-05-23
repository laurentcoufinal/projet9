import { TestBed } from '@angular/core/testing';
import { TraceIdService } from './trace-id.service';

describe('TraceIdService', () => {
  let service: TraceIdService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(TraceIdService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('runWithId should set and restore currentId', async () => {
    expect(service.getCurrentId()).toBeNull();

    await service.runWithId('test-id', async () => {
      expect(service.getCurrentId()).toBe('test-id');
    });

    expect(service.getCurrentId()).toBeNull();
  });

  it('generate should return a UUID string', () => {
    const id = service.generate();
    expect(id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    );
  });
});
