import assert from "node:assert/strict";
import test from "node:test";

import { PlaceService } from "../src/modules/place/place.service";
import { ConflictError } from "../src/utils/errors";

const baseCreateInput = {
  name: "The Cofftea",
  categoryId: "11111111-1111-1111-1111-111111111111",
  address: "123 Pho Hue, Ha Noi",
  priceRange: "",
  openingHours: "",
  phone: null,
  mapsUrl: "https://www.google.com/maps/place/The+Cofftea/",
  note: null,
  imageUrl: null,
  rating: 4.6,
  hasReminder: false,
  latitude: 21.0123,
  longitude: 105.85,
};

test("create rejects duplicate places that share the same Google Maps link", async () => {
  const service = createService({
    findDuplicateCandidates: async () => [
      {
        id: "existing-place",
        name: "The Cofftea",
        address: "123 Pho Hue, Ha Noi",
        mapsUrl: "https://www.google.com/maps/place/The+Cofftea/",
        latitude: 21.0123,
        longitude: 105.85,
      },
    ],
  });

  await assert.rejects(
    () =>
      service.create({
        ...baseCreateInput,
        mapsUrl:
          "https://www.google.com/maps/place/The+Cofftea/?hl=vi&entry=ttu",
      }),
    (error: unknown) => {
      assert(error instanceof ConflictError);
      assert.equal(
        error.message,
        'Dia diem "The Cofftea" da ton tai (trung lien ket Google Maps)',
      );
      return true;
    },
  );
});

test("create rejects near-identical place names at the same coordinates", async () => {
  const service = createService({
    findDuplicateCandidates: async () => [
      {
        id: "existing-place",
        name: "The Cofftea Ha Noi",
        address: "123 Pho Hue, Ha Noi, Viet Nam",
        mapsUrl: null,
        latitude: 21.01231,
        longitude: 105.85002,
      },
    ],
  });

  await assert.rejects(
    () => service.create(baseCreateInput),
    (error: unknown) => {
      assert(error instanceof ConflictError);
      assert.equal(
        error.message,
        'Dia diem "The Cofftea Ha Noi" co ve da ton tai (trung ten va vi tri ban do)',
      );
      return true;
    },
  );
});

test("create rejects same-name places with matching normalized addresses", async () => {
  const service = createService({
    findDuplicateCandidates: async () => [
      {
        id: "existing-place",
        name: "The Cofftea",
        address: "123 Pho Hue, Ha Noi, Viet Nam",
        mapsUrl: null,
        latitude: null,
        longitude: null,
      },
    ],
  });

  await assert.rejects(
    () =>
      service.create({
        ...baseCreateInput,
        mapsUrl: null,
        latitude: null,
        longitude: null,
      }),
    (error: unknown) => {
      assert(error instanceof ConflictError);
      assert.equal(
        error.message,
        'Dia diem "The Cofftea" da ton tai (trung ten va dia chi)',
      );
      return true;
    },
  );
});

test("update skips duplicate lookup when identity fields are unchanged", async () => {
  let duplicateChecks = 0;
  const service = createService({
    findById: async () => createStoredPlace(),
    findDuplicateCandidates: async () => {
      duplicateChecks += 1;
      return [];
    },
  });

  await service.update("existing-place", {
    note: "Updated note only",
  });

  assert.equal(duplicateChecks, 0);
});

test("create allows places that only share approximate coordinates", async () => {
  const service = createService({
    findDuplicateCandidates: async () => [
      {
        id: "existing-place",
        name: "Another Coffee House",
        address: "456 Tran Hung Dao, Ha Noi",
        mapsUrl: null,
        latitude: 21.01231,
        longitude: 105.85002,
      },
    ],
  });

  const created = await service.create(baseCreateInput);

  assert.equal(created.name, baseCreateInput.name);
});

function createService(overrides: Partial<Record<string, unknown>> = {}) {
  const repository = {
    findAll: async () => [],
    findById: async () => createStoredPlace(),
    create: async (data: typeof baseCreateInput) => ({
      id: "new-place",
      ...data,
    }),
    update: async (id: string, data: Record<string, unknown>) => ({
      ...createStoredPlace(),
      id,
      ...data,
    }),
    delete: async (id: string) => ({ id }),
    findDuplicateCandidates: async () => [],
    ...overrides,
  };

  return new PlaceService(repository as never);
}

function createStoredPlace() {
  return {
    id: "existing-place",
    ...baseCreateInput,
    category: null,
    schedules: [],
  };
}
