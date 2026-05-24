import { z } from 'zod';

const emailSchema = z.string().trim().toLowerCase().email();
const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(128, 'Password is too long')
  .regex(/[A-Za-z]/, 'Password must contain a letter')
  .regex(/\d/, 'Password must contain a number');
const codeSchema = z.string().trim().regex(/^\d{6}$/, 'Code must be 6 digits');

export const registerSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2, 'Name must be at least 2 characters').max(80),
    email: emailSchema,
    password: passwordSchema,
  }),
});

export const loginSchema = z.object({
  body: z.object({
    email: emailSchema,
    password: z.string().min(1, 'Password is required'),
  }),
});

export const googleLoginSchema = z.object({
  body: z.object({
    idToken: z.string().trim().min(20, 'Google ID token is required'),
  }),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().trim().min(20, 'Refresh token is required'),
  }),
});

export const logoutSchema = z.object({
  body: z.object({
    refreshToken: z.string().trim().min(20).optional().nullable(),
  }),
});

export const emailRequestSchema = z.object({
  body: z.object({
    email: emailSchema,
  }),
});

export const verifyEmailSchema = z.object({
  body: z.object({
    email: emailSchema,
    code: codeSchema,
  }),
});

export const resetPasswordSchema = z.object({
  body: z.object({
    email: emailSchema,
    code: codeSchema,
    password: passwordSchema,
  }),
});

export const updateMeSchema = z.object({
  body: z
    .object({
      name: z.string().trim().min(2).max(80).optional(),
      avatarUrl: z.url().optional().nullable(),
    })
    .refine((value) => Object.keys(value).length > 0, {
      message: 'At least one field is required',
    }),
});

export type RegisterInput = z.infer<typeof registerSchema>['body'];
export type LoginInput = z.infer<typeof loginSchema>['body'];
export type GoogleLoginInput = z.infer<typeof googleLoginSchema>['body'];
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>['body'];
export type UpdateMeInput = z.infer<typeof updateMeSchema>['body'];
