import assert from 'node:assert/strict';
import test from 'node:test';

import { CategoryService } from '../src/modules/category/category.service';
import { ConflictError, NotFoundError } from '../src/utils/errors';

const baseCategory = {
  id: 'category-1',
  name: 'Cafe',
  icon: 'coffee',
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  _count: { places: 0 },
};

test('category update rejects duplicate names from another category', async () => {
  const service = createService({
    findById: async () => baseCategory,
    findByName: async () => ({
      ...baseCategory,
      id: 'category-2',
      name: 'Restaurant',
    }),
  });

  await assert.rejects(
    () => service.update('category-1', { name: 'Restaurant' }),
    (error: unknown) => {
      assert(error instanceof ConflictError);
      assert.equal(error.message, 'Danh mục "Restaurant" đã tồn tại');
      return true;
    },
  );
});

test('category delete rejects categories that still have places', async () => {
  const service = createService({
    findById: async () => ({
      ...baseCategory,
      _count: { places: 2 },
    }),
  });

  await assert.rejects(
    () => service.delete('category-1'),
    (error: unknown) => {
      assert(error instanceof ConflictError);
      assert.deepEqual(error.details, { placeCount: 2 });
      return true;
    },
  );
});

test('category delete rejects missing categories', async () => {
  const service = createService({
    findById: async () => null,
  });

  await assert.rejects(
    () => service.delete('missing-category'),
    (error: unknown) => {
      assert(error instanceof NotFoundError);
      assert.equal(error.message, 'Category not found');
      return true;
    },
  );
});

function createService(overrides: Partial<Record<string, unknown>> = {}) {
  const repository = {
    findAll: async () => [],
    findByName: async () => null,
    findById: async () => baseCategory,
    create: async (data: { name: string; icon: string }) => ({
      ...baseCategory,
      ...data,
    }),
    update: async (id: string, data: { name?: string; icon?: string }) => ({
      ...baseCategory,
      id,
      ...data,
    }),
    delete: async (id: string) => ({ ...baseCategory, id }),
    ...overrides,
  };

  return new CategoryService(repository as never);
}
