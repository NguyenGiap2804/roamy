import { NextFunction, Request, Response } from 'express';
import { ZodType } from 'zod';

import { ValidationError } from './errors';

export function validate<T extends ZodType>(schema: T) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse({
      body: req.body,
      params: req.params,
      query: req.query,
    });

    if (!result.success) {
      return next(new ValidationError('Validation failed', result.error.flatten()));
    }

    const data = result.data as {
      body?: unknown;
      params?: Request['params'];
      query?: Request['query'];
    };

    if (data.body !== undefined) req.body = data.body;
    if (data.params !== undefined) {
      Object.defineProperty(req, 'params', { value: data.params, writable: true, enumerable: true, configurable: true });
    }
    if (data.query !== undefined) {
      Object.defineProperty(req, 'query', { value: data.query, writable: true, enumerable: true, configurable: true });
    }
    return next();
  };
}
