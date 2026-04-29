import { Prisma } from "@prisma/client";

import { ConflictError } from "../../utils/errors";
import { categoryRepository } from "./category.repository";
import { CategoryCreateInput } from "./category.model";

export class CategoryService {
  findAll() {
    return categoryRepository.findAll();
  }

  async create(data: CategoryCreateInput) {
    try {
      return await categoryRepository.create(data);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw new ConflictError("Category already exists");
      }

      throw error;
    }
  }
}

export const categoryService = new CategoryService();
