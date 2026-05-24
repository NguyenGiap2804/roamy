import { NextFunction, Request, Response } from 'express';

import { sendResponse } from '../../utils/response';
import { requireUserId } from './auth.middleware';
import { authService } from './auth.service';

export class AuthController {
  async register(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        201,
        'Registration started successfully',
        await authService.register(req.body),
      );
    } catch (error) {
      return next(error);
    }
  }

  async login(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Logged in successfully',
        await authService.login(req.body, authContext(req)),
      );
    } catch (error) {
      return next(error);
    }
  }

  async google(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Logged in with Google successfully',
        await authService.loginWithGoogle(req.body, authContext(req)),
      );
    } catch (error) {
      return next(error);
    }
  }

  async refresh(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Session refreshed successfully',
        await authService.refresh(req.body.refreshToken, authContext(req)),
      );
    } catch (error) {
      return next(error);
    }
  }

  async logout(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Logged out successfully',
        await authService.logout(req.body.refreshToken),
      );
    } catch (error) {
      return next(error);
    }
  }

  async resendEmail(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Verification email sent if the account exists',
        await authService.resendVerification(req.body.email),
      );
    } catch (error) {
      return next(error);
    }
  }

  async verifyEmail(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Email verified successfully',
        await authService.verifyEmail(req.body.email, req.body.code, authContext(req)),
      );
    } catch (error) {
      return next(error);
    }
  }

  async forgotPassword(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Password reset email sent if the account exists',
        await authService.forgotPassword(req.body.email),
      );
    } catch (error) {
      return next(error);
    }
  }

  async resetPassword(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Password reset successfully',
        await authService.resetPassword(req.body, authContext(req)),
      );
    } catch (error) {
      return next(error);
    }
  }

  async me(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Profile fetched successfully',
        await authService.me(requireUserId(req)),
      );
    } catch (error) {
      return next(error);
    }
  }

  async updateMe(req: Request, res: Response, next: NextFunction) {
    try {
      return sendResponse(
        res,
        200,
        'Profile updated successfully',
        await authService.updateMe(requireUserId(req), req.body),
      );
    } catch (error) {
      return next(error);
    }
  }
}

export const authController = new AuthController();

function authContext(req: Request) {
  return {
    deviceId: req.deviceId ?? null,
    userAgent: req.get('user-agent') ?? null,
    ipAddress: req.ip,
  };
}
