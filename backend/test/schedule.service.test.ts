import assert from "node:assert/strict";
import test from "node:test";

import { ScheduleService } from "../src/modules/schedule/schedule.service";
import { NotFoundError, ValidationError } from "../src/utils/errors";

const userId = "user-1";
const quickInput = {
  title: "AN cafe",
  note: "Ca phe, view dep, nen ghe buoi sang",
  mapsUrl: "https://maps.app.goo.gl/abc123",
  date: "2099-01-10",
  time: "10:00-11:00",
  status: "UPCOMING" as const,
  hasReminder: false,
};

test("create allows quick schedules without creating a place", async () => {
  let placeLookups = 0;
  const service = createService({
    places: {
      findById: async () => {
        placeLookups += 1;
        return null;
      },
    },
  });

  const schedule = await service.create(userId, quickInput);

  assert.equal(schedule.title, quickInput.title);
  assert.equal(schedule.placeId, null);
  assert.equal(placeLookups, 0);
});

test("create rejects quick schedules without title or Google Maps link", async () => {
  const service = createService();

  await assert.rejects(
    () =>
      service.create(userId, {
        ...quickInput,
        title: "",
        mapsUrl: "",
      }),
    (error: unknown) => {
      assert(error instanceof ValidationError);
      assert.equal(error.message, "Quick schedule requires title and Google Maps link");
      return true;
    },
  );
});

test("create still requires existing user-owned place when placeId is provided", async () => {
  const service = createService({
    places: {
      findById: async () => null,
    },
  });

  await assert.rejects(
    () =>
      service.create(userId, {
        ...quickInput,
        placeId: "11111111-1111-1111-1111-111111111111",
      }),
    (error: unknown) => {
      assert(error instanceof NotFoundError);
      assert.equal(error.message, "Place not found");
      return true;
    },
  );
});

function createService(
  overrides: {
    schedules?: Partial<Record<string, unknown>>;
    places?: Partial<Record<string, unknown>>;
  } = {},
) {
  const schedules = {
    findAll: async () => [],
    findById: async (id: string) => ({
      id,
      userId,
      placeId: null,
      title: quickInput.title,
      mapsUrl: quickInput.mapsUrl,
    }),
    create: async (_userId: string, data: Record<string, unknown>) => ({
      id: "schedule-1",
      userId: _userId,
      placeId: data.placeId ?? null,
      ...data,
    }),
    update: async (id: string, data: Record<string, unknown>) => ({
      id,
      userId,
      ...data,
    }),
    delete: async (id: string) => ({ id }),
    ...overrides.schedules,
  };

  const places = {
    findById: async (id: string) => ({ id, userId }),
    ...overrides.places,
  };

  return new ScheduleService(schedules as never, places as never);
}
