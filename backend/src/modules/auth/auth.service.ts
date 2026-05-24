import { randomInt } from 'crypto';
import bcrypt from 'bcryptjs';
import { AuthProvider, EmailTokenType, User } from '@prisma/client';

import { prisma } from '../../config/db';
import { AppError, ConflictError, NotFoundError } from '../../utils/errors';
import { sendAuthEmail } from './auth.email';
import { verifyGoogleIdToken } from './auth.google';
import {
  createRefreshToken,
  hashSecret,
  signAccessToken,
} from './auth.tokens';
import {
  GoogleLoginInput,
  LoginInput,
  RegisterInput,
  ResetPasswordInput,
  UpdateMeInput,
} from './auth.model';

type AuthContext = {
  deviceId?: string | null;
  userAgent?: string | null;
  ipAddress?: string | null;
};

const refreshTokenTtlMs = 30 * 24 * 60 * 60 * 1000;
const emailTokenTtlMs = 15 * 60 * 1000;
const maxEmailTokenAttempts = 5;

export class AuthService {
  async register(input: RegisterInput, context: AuthContext) {
    const email = normalizeEmail(input.email);
    const passwordHash = await bcrypt.hash(input.password, 12);
    const existing = await prisma.user.findUnique({ where: { email } });

    if (existing?.passwordHash && existing.emailVerifiedAt) {
      throw new ConflictError('Email is already registered');
    }

    const user = existing
      ? await prisma.user.update({
          where: { id: existing.id },
          data: {
            name: existing.name || input.name,
            passwordHash,
            emailVerifiedAt: existing.emailVerifiedAt ?? new Date(),
            lastLoginAt: new Date(),
            accounts: {
              upsert: {
                where: {
                  provider_providerAccountId: {
                    provider: AuthProvider.PASSWORD,
                    providerAccountId: email,
                  },
                },
                update: { email },
                create: {
                  provider: AuthProvider.PASSWORD,
                  providerAccountId: email,
                  email,
                },
              },
            },
          },
        })
      : await prisma.user.create({
          data: {
            email,
            name: input.name,
            passwordHash,
            emailVerifiedAt: new Date(),
            lastLoginAt: new Date(),
            accounts: {
              create: {
                provider: AuthProvider.PASSWORD,
                providerAccountId: email,
                email,
              },
            },
          },
        });

    return this.createSession(user, context);
  }

  async login(input: LoginInput, context: AuthContext) {
    const user = await prisma.user.findUnique({
      where: { email: normalizeEmail(input.email) },
    });

    if (!user?.passwordHash) {
      throw new AppError(401, 'Invalid email or password');
    }

    const validPassword = await bcrypt.compare(input.password, user.passwordHash);
    if (!validPassword) {
      throw new AppError(401, 'Invalid email or password');
    }

    if (!user.emailVerifiedAt) {
      throw new AppError(403, 'Email is not verified');
    }

    return this.createSession(
      await prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date() },
      }),
      context,
    );
  }

  async loginWithGoogle(input: GoogleLoginInput, context: AuthContext) {
    const profile = await verifyGoogleIdToken(input.idToken);
    const existingAccount = await prisma.authAccount.findUnique({
      where: {
        provider_providerAccountId: {
          provider: AuthProvider.GOOGLE,
          providerAccountId: profile.providerAccountId,
        },
      },
      include: { user: true },
    });

    const user = existingAccount
      ? await prisma.user.update({
          where: { id: existingAccount.userId },
          data: {
            name: existingAccount.user.name || profile.name,
            avatarUrl: existingAccount.user.avatarUrl ?? profile.avatarUrl,
            emailVerifiedAt: existingAccount.user.emailVerifiedAt ?? new Date(),
            lastLoginAt: new Date(),
          },
        })
      : await this.createOrLinkGoogleUser(profile);

    return this.createSession(user, context);
  }

  async refresh(refreshToken: string, context: AuthContext) {
    const tokenHash = hashSecret(refreshToken);
    const current = await prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (
      !current ||
      current.revokedAt ||
      current.expiresAt.getTime() <= Date.now()
    ) {
      throw new AppError(401, 'Invalid refresh token');
    }

    const rawRefreshToken = createRefreshToken();
    const next = await prisma.refreshToken.create({
      data: {
        userId: current.userId,
        tokenHash: hashSecret(rawRefreshToken),
        expiresAt: new Date(Date.now() + refreshTokenTtlMs),
        deviceId: context.deviceId ?? null,
        userAgent: context.userAgent ?? null,
        ipAddress: context.ipAddress ?? null,
      },
    });

    await prisma.refreshToken.update({
      where: { id: current.id },
      data: { revokedAt: new Date(), replacedByTokenId: next.id },
    });

    return {
      user: serializeUser(current.user),
      accessToken: signAccessToken({
        userId: current.user.id,
        email: current.user.email,
      }),
      refreshToken: rawRefreshToken,
    };
  }

  async logout(refreshToken?: string | null) {
    if (refreshToken) {
      await prisma.refreshToken.updateMany({
        where: { tokenHash: hashSecret(refreshToken), revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    return { loggedOut: true };
  }

  async resendVerification(emailInput: string) {
    const user = await prisma.user.findUnique({
      where: { email: normalizeEmail(emailInput) },
    });
    if (user && !user.emailVerifiedAt) {
      await this.sendVerificationCode(user);
    }
    return { sent: true };
  }

  async verifyEmail(emailInput: string, code: string, context: AuthContext) {
    const user = await this.findUserByEmail(emailInput);
    await this.consumeEmailToken(user.id, EmailTokenType.VERIFY_EMAIL, code);
    const verifiedUser = await prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerifiedAt: user.emailVerifiedAt ?? new Date(),
        lastLoginAt: new Date(),
      },
    });
    return this.createSession(verifiedUser, context);
  }

  async forgotPassword(emailInput: string) {
    const user = await prisma.user.findUnique({
      where: { email: normalizeEmail(emailInput) },
    });
    if (user) {
      const code = await this.createEmailToken(
        user.id,
        EmailTokenType.RESET_PASSWORD,
      );
      await sendAuthEmail({
        to: user.email,
        subject: 'Reset your Roamy password',
        text: `Your Roamy password reset code is ${code}. It expires in 15 minutes.`,
      });
    }
    return { sent: true };
  }

  async resetPassword(input: ResetPasswordInput, context: AuthContext) {
    const user = await this.findUserByEmail(input.email);
    await this.consumeEmailToken(
      user.id,
      EmailTokenType.RESET_PASSWORD,
      input.code,
    );
    const passwordHash = await bcrypt.hash(input.password, 12);
    const updated = await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        emailVerifiedAt: user.emailVerifiedAt ?? new Date(),
        lastLoginAt: new Date(),
        accounts: {
          upsert: {
            where: {
              provider_providerAccountId: {
                provider: AuthProvider.PASSWORD,
                providerAccountId: user.email,
              },
            },
            update: { email: user.email },
            create: {
              provider: AuthProvider.PASSWORD,
              providerAccountId: user.email,
              email: user.email,
            },
          },
        },
      },
    });
    await prisma.refreshToken.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return this.createSession(updated, context);
  }

  async me(userId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundError('User not found');
    }
    return serializeUser(user);
  }

  async updateMe(userId: string, input: UpdateMeInput) {
    const user = await prisma.user.update({
      where: { id: userId },
      data: input,
    });
    return serializeUser(user);
  }

  private async createOrLinkGoogleUser(profile: {
    providerAccountId: string;
    email: string;
    name: string;
    avatarUrl?: string | null;
  }) {
    const existingUser = await prisma.user.findUnique({
      where: { email: profile.email },
    });

    if (existingUser) {
      return prisma.user.update({
        where: { id: existingUser.id },
        data: {
          name: existingUser.name || profile.name,
          avatarUrl: existingUser.avatarUrl ?? profile.avatarUrl,
          emailVerifiedAt: existingUser.emailVerifiedAt ?? new Date(),
          lastLoginAt: new Date(),
          accounts: {
            create: {
              provider: AuthProvider.GOOGLE,
              providerAccountId: profile.providerAccountId,
              email: profile.email,
            },
          },
        },
      });
    }

    return prisma.user.create({
      data: {
        email: profile.email,
        name: profile.name,
        avatarUrl: profile.avatarUrl,
        emailVerifiedAt: new Date(),
        lastLoginAt: new Date(),
        accounts: {
          create: {
            provider: AuthProvider.GOOGLE,
            providerAccountId: profile.providerAccountId,
            email: profile.email,
          },
        },
      },
    });
  }

  private async createSession(user: User, context: AuthContext) {
    const rawRefreshToken = createRefreshToken();
    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: hashSecret(rawRefreshToken),
        expiresAt: new Date(Date.now() + refreshTokenTtlMs),
        deviceId: context.deviceId ?? null,
        userAgent: context.userAgent ?? null,
        ipAddress: context.ipAddress ?? null,
      },
    });

    return {
      user: serializeUser(user),
      accessToken: signAccessToken({ userId: user.id, email: user.email }),
      refreshToken: rawRefreshToken,
    };
  }

  private async sendVerificationCode(user: User) {
    const code = await this.createEmailToken(user.id, EmailTokenType.VERIFY_EMAIL);
    await sendAuthEmail({
      to: user.email,
      subject: 'Verify your Roamy account',
      text: `Your Roamy verification code is ${code}. It expires in 15 minutes.`,
    });
  }

  private async createEmailToken(userId: string, type: EmailTokenType) {
    const code = randomInt(100000, 1000000).toString();
    await prisma.emailToken.updateMany({
      where: { userId, type, consumedAt: null },
      data: { consumedAt: new Date() },
    });
    await prisma.emailToken.create({
      data: {
        userId,
        type,
        codeHash: hashSecret(code),
        expiresAt: new Date(Date.now() + emailTokenTtlMs),
      },
    });
    return code;
  }

  private async consumeEmailToken(
    userId: string,
    type: EmailTokenType,
    code: string,
  ) {
    const token = await prisma.emailToken.findFirst({
      where: { userId, type, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (!token) {
      throw new AppError(400, 'Invalid verification code');
    }

    if (token.expiresAt.getTime() <= Date.now()) {
      throw new AppError(400, 'Verification code has expired');
    }

    if (token.attempts >= maxEmailTokenAttempts) {
      throw new AppError(429, 'Too many verification attempts');
    }

    if (token.codeHash !== hashSecret(code)) {
      await prisma.emailToken.update({
        where: { id: token.id },
        data: { attempts: { increment: 1 } },
      });
      throw new AppError(400, 'Invalid verification code');
    }

    await prisma.emailToken.update({
      where: { id: token.id },
      data: { consumedAt: new Date() },
    });
  }

  private async findUserByEmail(emailInput: string) {
    const user = await prisma.user.findUnique({
      where: { email: normalizeEmail(emailInput) },
    });
    if (!user) {
      throw new NotFoundError('User not found');
    }
    return user;
  }
}

export const authService = new AuthService();

export function serializeUser(user: User) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    avatarUrl: user.avatarUrl,
    emailVerified: Boolean(user.emailVerifiedAt),
    emailVerifiedAt: user.emailVerifiedAt,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
  };
}

function normalizeEmail(value: string) {
  return value.trim().toLowerCase();
}
