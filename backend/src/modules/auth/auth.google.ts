import { AppError } from '../../utils/errors';

export type GoogleProfile = {
  providerAccountId: string;
  email: string;
  name: string;
  avatarUrl?: string | null;
};

type GoogleTokenInfo = {
  sub?: string;
  aud?: string;
  email?: string;
  email_verified?: string | boolean;
  name?: string;
  picture?: string;
};

export async function verifyGoogleIdToken(idToken: string): Promise<GoogleProfile> {
  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
  );

  if (!response.ok) {
    throw new AppError(401, 'Invalid Google token');
  }

  const data = (await response.json()) as GoogleTokenInfo;
  const allowedAudiences = googleAudiences();
  if (
    allowedAudiences.length > 0 &&
    (!data.aud || !allowedAudiences.includes(data.aud))
  ) {
    throw new AppError(401, 'Google token audience is not allowed');
  }

  if (!data.sub || !data.email || data.email_verified !== true && data.email_verified !== 'true') {
    throw new AppError(401, 'Google account email is not verified');
  }

  return {
    providerAccountId: data.sub,
    email: data.email.trim().toLowerCase(),
    name: data.name?.trim() || data.email.split('@')[0],
    avatarUrl: data.picture ?? null,
  };
}

function googleAudiences() {
  const raw = process.env.GOOGLE_AUTH_AUDIENCES;
  if (!raw && process.env.NODE_ENV === 'production') {
    throw new AppError(500, 'GOOGLE_AUTH_AUDIENCES is not configured');
  }
  return (raw ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
}
