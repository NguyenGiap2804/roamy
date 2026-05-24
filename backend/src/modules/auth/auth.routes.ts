import { Router } from 'express';

import { validate } from '../../utils/validate';
import { authenticateUser } from './auth.middleware';
import { authController } from './auth.controller';
import {
  emailRequestSchema,
  googleLoginSchema,
  loginSchema,
  logoutSchema,
  refreshSchema,
  registerSchema,
  resetPasswordSchema,
  updateMeSchema,
  verifyEmailSchema,
} from './auth.model';

export const authRoutes = Router();
export const meRoutes = Router();

authRoutes.post('/register', validate(registerSchema), authController.register);
authRoutes.post('/login', validate(loginSchema), authController.login);
authRoutes.post('/google', validate(googleLoginSchema), authController.google);
authRoutes.post('/refresh', validate(refreshSchema), authController.refresh);
authRoutes.post('/logout', validate(logoutSchema), authController.logout);
authRoutes.post('/email/resend', validate(emailRequestSchema), authController.resendEmail);
authRoutes.post('/email/verify', validate(verifyEmailSchema), authController.verifyEmail);
authRoutes.post('/password/forgot', validate(emailRequestSchema), authController.forgotPassword);
authRoutes.post('/password/reset', validate(resetPasswordSchema), authController.resetPassword);
meRoutes.use(authenticateUser);
meRoutes.get('/', authController.me);
meRoutes.patch('/', validate(updateMeSchema), authController.updateMe);
