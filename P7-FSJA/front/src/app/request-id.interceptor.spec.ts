import { TestBed } from '@angular/core/testing';
import {
  HttpTestingController,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import {
  HttpClient,
  provideHttpClient,
  withInterceptors,
} from '@angular/common/http';
import { requestIdInterceptor } from './request-id.interceptor';
import { TraceIdService } from './trace-id.service';
import { API_BASE_URL } from './config';

describe('requestIdInterceptor', () => {
  let http: HttpClient;
  let httpMock: HttpTestingController;
  let traceId: TraceIdService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([requestIdInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    httpMock = TestBed.inject(HttpTestingController);
    traceId = TestBed.inject(TraceIdService);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should add X-Request-Id header from TraceIdService context', () => {
    traceId.runWithId('fixed-request-id', () => {
      http.get(`${API_BASE_URL}/persons`).subscribe();
      const req = httpMock.expectOne(`${API_BASE_URL}/persons`);
      expect(req.request.headers.get('X-Request-Id')).toBe('fixed-request-id');
      req.flush({ _embedded: { persons: [] } });
    });
  });

  it('should generate X-Request-Id when no context', () => {
    http.get(`${API_BASE_URL}/persons`).subscribe();
    const req = httpMock.expectOne(`${API_BASE_URL}/persons`);
    const header = req.request.headers.get('X-Request-Id');
    expect(header).toBeTruthy();
    expect(header).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    );
    req.flush({ _embedded: { persons: [] } });
  });
});
