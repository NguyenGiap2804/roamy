import assert from "node:assert/strict";
import test from "node:test";
import bcrypt from "bcryptjs";

import { prisma } from "../src/config/db";
import { adminService } from "../src/modules/admin/admin.service";
import { ConflictError, ValidationError } from "../src/utils/errors";

test("admin creates a verified password user with a one-time temporary password", async () => {
  const restore = mockPrisma({
    user: {
      findUnique: async () => null,
      create: async (args: Record<string, any>) => {
        assert.equal(args.data.email, "new.user@example.com");
        assert.equal(args.data.name, "New User");
        assert(args.data.emailVerifiedAt instanceof Date);
        assert.equal(args.data.accounts.create.provider, "PASSWORD");
        assert.equal(
          args.data.accounts.create.providerAccountId,
          "new.user@example.com",
        );

        return {
          id: "user-1",
          email: args.data.email,
          name: args.data.name,
          avatarUrl: null,
          emailVerifiedAt: args.data.emailVerifiedAt,
          lastLoginAt: null,
          createdAt: new Date("2026-01-01T00:00:00.000Z"),
          accounts: [{ provider: "PASSWORD", createdAt: new Date() }],
          _count: { categories: 0, places: 0, schedules: 0 },
          passwordHash: args.data.passwordHash,
        };
      },
    },
  });

  try {
    const result = await adminService.createUser({
      name: "New User",
      email: " NEW.USER@example.com ",
    });

    assert.equal(result.user.email, "new.user@example.com");
    assert.match(result.temporaryPassword, /^Roamy/);
    assert.equal(
      await bcrypt.compare(
        result.temporaryPassword,
        (result.user as any).passwordHash,
      ),
      true,
    );
  } finally {
    restore();
  }
});

test("admin create user rejects duplicate email", async () => {
  const restore = mockPrisma({
    user: {
      findUnique: async () => ({ id: "existing-user" }),
    },
  });

  try {
    await assert.rejects(
      () =>
        adminService.createUser({
          name: "Existing",
          email: "used@example.com",
        }),
      (error: unknown) => {
        assert(error instanceof ConflictError);
        assert.equal(error.message, "Email đã tồn tại");
        return true;
      },
    );
  } finally {
    restore();
  }
});

test("admin list places applies userId server-side filter", async () => {
  let countWhere: unknown;
  let findWhere: unknown;
  const restore = mockPrisma({
    place: {
      count: async (args: Record<string, unknown>) => {
        countWhere = args.where;
        return 0;
      },
      findMany: async (args: Record<string, unknown>) => {
        findWhere = args.where;
        return [];
      },
    },
  });

  try {
    await adminService.listPlaces({ userId: "user-1", q: "Cafe" });
    assert.deepEqual(countWhere, findWhere);
    assert.deepEqual(countWhere, {
      AND: [
        {
          OR: [
            { name: { contains: "Cafe", mode: "insensitive" } },
            { address: { contains: "Cafe", mode: "insensitive" } },
            { category: { name: { contains: "Cafe", mode: "insensitive" } } },
          ],
        },
        { userId: "user-1" },
      ],
    });
  } finally {
    restore();
  }
});

test("admin delete user requires matching confirmation email", async () => {
  const restore = mockPrisma({
    user: {
      findUnique: async () => ({ id: "user-1", email: "owner@example.com" }),
    },
  });

  try {
    await assert.rejects(
      () => adminService.deleteUser("user-1", "wrong@example.com"),
      (error: unknown) => {
        assert(error instanceof ValidationError);
        assert.equal(error.message, "Email xác nhận không khớp");
        return true;
      },
    );
  } finally {
    restore();
  }
});

test("admin delete user removes user-owned records before deleting user", async () => {
  const deletedModels: string[] = [];
  const tx = {
    schedule: modelDeleteMany("schedule", deletedModels),
    place: modelDeleteMany("place", deletedModels),
    category: modelDeleteMany("category", deletedModels),
    refreshToken: modelDeleteMany("refreshToken", deletedModels),
    authAccount: modelDeleteMany("authAccount", deletedModels),
    emailToken: modelDeleteMany("emailToken", deletedModels),
    imageAsset: modelDeleteMany("imageAsset", deletedModels),
    apiRequestLog: modelDeleteMany("apiRequestLog", deletedModels),
    apiErrorLog: modelDeleteMany("apiErrorLog", deletedModels),
    systemEvent: modelDeleteMany("systemEvent", deletedModels),
    user: {
      delete: async (args: Record<string, unknown>) => {
        deletedModels.push("user");
        assert.deepEqual(args, { where: { id: "user-1" } });
      },
    },
  };
  const restore = mockPrisma({
    user: {
      findUnique: async () => ({ id: "user-1", email: "owner@example.com" }),
    },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  });

  try {
    const result = await adminService.deleteUser("user-1", "owner@example.com");

    assert.deepEqual(deletedModels, [
      "schedule",
      "place",
      "category",
      "refreshToken",
      "authAccount",
      "emailToken",
      "imageAsset",
      "apiRequestLog",
      "apiErrorLog",
      "systemEvent",
      "user",
    ]);
    assert.deepEqual(result, {
      id: "user-1",
      email: "owner@example.com",
      deleted: true,
      deletedCounts: {
        schedules: 1,
        places: 1,
        categories: 1,
        refreshTokens: 1,
        authAccounts: 1,
        emailTokens: 1,
        imageAssets: 1,
        apiRequestLogs: 1,
        apiErrorLogs: 1,
        systemEvents: 1,
      },
    });
  } finally {
    restore();
  }
});

function modelDeleteMany(name: string, deletedModels: string[]) {
  return {
    deleteMany: async (args: Record<string, unknown>) => {
      deletedModels.push(name);
      assert.deepEqual(args, { where: { userId: "user-1" } });
      return { count: 1 };
    },
  };
}

function mockPrisma(overrides: Record<string, unknown>) {
  const originals = new Map<string, unknown>();
  for (const [key, value] of Object.entries(overrides)) {
    originals.set(key, (prisma as unknown as Record<string, unknown>)[key]);
    Object.defineProperty(prisma, key, {
      value,
      configurable: true,
      writable: true,
    });
  }

  return () => {
    for (const [key, value] of originals) {
      Object.defineProperty(prisma, key, {
        value,
        configurable: true,
        writable: true,
      });
    }
  };
}
