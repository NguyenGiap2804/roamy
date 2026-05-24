import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();
const legacyUserId = '00000000-0000-4000-8000-000000000001';

function normalizeEmail(value?: string | null) {
  const email = value?.trim().toLowerCase();
  return email || 'legacy@roamy.local';
}

async function main() {
  const email = normalizeEmail(process.env.LEGACY_OWNER_EMAIL);
  const name = email === 'legacy@roamy.local' ? 'Roamy Legacy Owner' : 'Roamy Owner';
  const now = new Date();

  const existingOwner = await prisma.user.findUnique({ where: { email } });
  const legacyUser = await prisma.user.findUnique({ where: { id: legacyUserId } });

  const owner =
    existingOwner ??
    (await prisma.user.upsert({
      where: { id: legacyUserId },
      update: {
        email,
        name,
        emailVerifiedAt: legacyUser?.emailVerifiedAt ?? now,
      },
      create: {
        id: legacyUserId,
        email,
        name,
        emailVerifiedAt: now,
      },
    }));

  if (owner.id !== legacyUserId) {
    await prisma.$transaction([
      prisma.category.updateMany({
        where: { userId: legacyUserId },
        data: { userId: owner.id },
      }),
      prisma.place.updateMany({
        where: { userId: legacyUserId },
        data: { userId: owner.id },
      }),
      prisma.schedule.updateMany({
        where: { userId: legacyUserId },
        data: { userId: owner.id },
      }),
    ]);
  }

  await prisma.systemEvent.create({
    data: {
      type: 'maintenance',
      action: 'legacy_owner.backfill',
      resourceType: 'user',
      resourceId: owner.id,
      userId: owner.id,
      message: `Legacy data assigned to ${owner.email}`,
      metadata: {
        legacyUserId,
        legacyOwnerEmailConfigured: Boolean(process.env.LEGACY_OWNER_EMAIL),
      },
    },
  });

  console.log(`Legacy owner ready: ${owner.email} (${owner.id})`);
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
