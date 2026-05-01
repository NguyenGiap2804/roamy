import { Prisma } from "@prisma/client";

import { ConflictError } from "../../utils/errors";
import { categoryRepository } from "./category.repository";
import { CategoryCreateInput } from "./category.model";

export class CategoryService {
  findAll() {
    return categoryRepository.findAll();
  }

  async create(data: CategoryCreateInput) {
    const existingCategory = await categoryRepository.findByName(data.name);
    if (existingCategory) {
      throw new ConflictError(_duplicateCategoryMessage(existingCategory.name));
    }

    try {
      return await categoryRepository.create(data);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw new ConflictError(_duplicateCategoryMessage(data.name));
      }

      throw error;
    }
  }
}

export const categoryService = new CategoryService();

function _duplicateCategoryMessage(name: string) {
  return 'Danh mục "$name" đã tồn tại';
}
