import { NextFunction, Request, Response } from 'express';

import { AppError } from '../../utils/errors';
import { verifyAccessToken } from './auth.tokens';

export function authenticateUser(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  const payload = readAccessToken(req);
  if (!payload) {
    return next(new AppError(401, 'Authentication required'));
  }

  req.userId = payload.sub;
  req.userEmail = payload.email;
  return next();
}

export function optionalUser(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  const payload = readAccessToken(req);
  if (payload) {
    req.userId = payload.sub;
    req.userEmail = payload.email;
  }
  return next();
}

function readAccessToken(req: Request) {
  const header = req.get('authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7).trim() : '';
  return token ? verifyAccessToken(token) : null;
}

export function requireUserId(req: Request) {
  if (!req.userId) {
    throw new AppError(401, 'Authentication required');
  }
  return req.userId;
}
