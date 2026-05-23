import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { TraceIdService } from './trace-id.service';

export const requestIdInterceptor: HttpInterceptorFn = (req, next) => {
  const trace = inject(TraceIdService);
  const id = trace.getCurrentId() ?? trace.generate();
  return next(req.clone({ setHeaders: { 'X-Request-Id': id } }));
};
